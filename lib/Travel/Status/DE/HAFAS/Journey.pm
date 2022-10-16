package Travel::Status::DE::HAFAS::Journey;

use strict;
use warnings;
use 5.014;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use parent 'Class::Accessor';

our $VERSION = '3.01';

Travel::Status::DE::HAFAS::Journey->mk_ro_accessors(
	qw(sched_date date sched_datetime datetime info is_cancelled operator delay
	  sched_time time train route route_end origin destination)
);

sub new {
	my ( $obj, %opt ) = @_;

	my @locL  = @{ $opt{common}{locL}  // [] };
	my @prodL = @{ $opt{common}{prodL} // [] };
	my @opL   = @{ $opt{common}{opL}   // [] };
	my @icoL  = @{ $opt{common}{icoL}  // [] };
	my @remL  = @{ $opt{common}{remL}  // [] };
	my @himL  = @{ $opt{common}{himL}  // [] };

	my $hafas   = $opt{hafas};
	my $journey = $opt{journey};

	my $date = $journey->{date};

	my $destination  = $journey->{dirTxt};
	my $is_cancelled = $journey->{isCncl};
	my $jid          = $journey->{jid};

	my $product    = $prodL[ $journey->{prodX} ];
	my $train      = $product->{prodCtx}{name};
	my $train_type = $product->{prodCtx}{catOutS};
	my $line_no    = $product->{prodCtx}{line};

	my $operator;
	if ( defined $product->{oprX} ) {
		if ( my $opref = $opL[ $product->{oprX} ] ) {
			$operator = $opref->{name};
		}
	}

	my @messages;
	for my $msg ( @{ $journey->{msgL} // [] } ) {
		if ( $msg->{type} eq 'REM' and defined $msg->{remX} ) {
			push( @messages, $hafas->add_message( $remL[ $msg->{remX} ] ) );
		}
		elsif ( $msg->{type} eq 'HIM' and defined $msg->{himX} ) {
			push( @messages, $hafas->add_message( $himL[ $msg->{himX} ], 1 ) );
		}
		else {
			say "Unknown message type $msg->{type}";
		}
	}

	my @stops;
	for my $stop ( @{ $journey->{stopL} // [] } ) {
		my $loc       = $locL[ $stop->{locX} ];
		my $sched_arr = $stop->{aTimeS};
		my $rt_arr    = $stop->{aTimeR};
		my $sched_dep = $stop->{dTimeS};
		my $rt_dep    = $stop->{dTimeR};

		for my $timestr ( $sched_arr, $rt_arr, $sched_dep, $rt_dep ) {
			if ( not defined $timestr ) {
				next;
			}
			if ( length($timestr) == 8 ) {

				# arrival time includes a day offset
				my $offset_date = $hafas->{now}->clone;
				$offset_date->add( days => substr( $timestr, 0, 2, q{} ) );
				$offset_date = $offset_date->strftime('%Y%m%d');
				$timestr     = $hafas->{strptime_obj}
				  ->parse_datetime("${offset_date}T${timestr}");
			}
			else {
				$timestr
				  = $hafas->{strptime_obj}
				  ->parse_datetime("${date}T${timestr}");
			}
		}

		my $arr_delay
		  = ( $sched_arr and $rt_arr )
		  ? ( $rt_arr->epoch - $sched_arr->epoch ) / 60
		  : undef;

		my $dep_delay
		  = ( $sched_dep and $rt_dep )
		  ? ( $rt_dep->epoch - $sched_dep->epoch ) / 60
		  : undef;

		push(
			@stops,
			{
				name      => $loc->{name},
				eva       => $loc->{extId} + 0,
				sched_arr => $sched_arr,
				rt_arr    => $rt_arr,
				sched_dep => $sched_dep,
				rt_dep    => $rt_dep,
				arr       => $rt_arr // $sched_arr,
				arr_delay => $arr_delay,
				dep       => $rt_dep // $sched_dep,
				dep_delay => $dep_delay,
				delay     => $dep_delay // $arr_delay
			}
		);
	}

	if ( $journey->{stbStop} ) {
		shift @stops;
	}

	my $ref = {
		datetime_now => $hafas->{now},
		is_cancelled => $is_cancelled,
		train        => $train,
		operator     => $operator,
		route_end    => $destination,
		messages     => \@messages,
		route        => \@stops,
	};

	if ( $hafas->{arrivals} ) {
		$ref->{origin} = $ref->{route_end};
	}
	else {
		$ref->{destination} = $ref->{route_end};
	}

	bless( $ref, $obj );

	if ( $journey->{stbStop} ) {
		$ref->{platform}     = $journey->{stbStop}{dPlatfS};
		$ref->{new_platform} = $journey->{stbStop}{dPlatfR};

		my $time_s
		  = $journey->{stbStop}{ $hafas->{arrivals} ? 'aTimeS' : 'dTimeS' };
		my $time_r
		  = $journey->{stbStop}{ $hafas->{arrivals} ? 'aTimeR' : 'dTimeR' };

		my $datetime_s
		  = $hafas->{strptime_obj}->parse_datetime("${date}T${time_s}");
		my $datetime_r
		  = $time_r
		  ? $hafas->{strptime_obj}->parse_datetime("${date}T${time_r}")
		  : undef;

		my $delay
		  = $datetime_r
		  ? ( $datetime_r->epoch - $datetime_s->epoch ) / 60
		  : undef;

		$ref->{sched_datetime} = $datetime_s;
		$ref->{rt_datetime}    = $datetime_r;
		$ref->{datetime}       = $datetime_r // $datetime_s;
		$ref->{delay}          = $delay;

		if ( $ref->{delay} ) {
			$ref->{datetime} = $ref->{rt_datetime};
		}
		else {
			$ref->{datetime} = $ref->{sched_datetime};
		}

		$ref->{date}       = $ref->{datetime}->strftime('%d.%m.%Y');
		$ref->{time}       = $ref->{datetime}->strftime('%H:%M');
		$ref->{sched_date} = $ref->{sched_datetime}->strftime('%d.%m.%Y');
		$ref->{sched_time} = $ref->{sched_datetime}->strftime('%H:%M');
	}
	if ( $opt{polyline} ) {
		$ref->{polyline} = $opt{polyline};
	}

	return $ref;
}

sub countdown {
	my ($self) = @_;

	$self->{countdown}
	  //= $self->datetime->subtract_datetime( $self->{datetime_now} )
	  ->in_units('minutes');

	return $self->{countdown};
}

sub countdown_sec {
	my ($self) = @_;

	$self->{countdown_sec}
	  //= $self->datetime->subtract_datetime( $self->{datetime_now} )
	  ->in_units('seconds');

	return $self->{countdown_sec};
}

sub line {
	my ($self) = @_;

	return $self->{train};
}

sub is_changed_platform {
	my ($self) = @_;

	if ( defined $self->{new_platform} and defined $self->{platform} ) {
		if ( $self->{new_platform} ne $self->{platform} ) {
			return 1;
		}
		return 0;
	}
	if ( defined $self->{net_platform} ) {
		return 1;
	}

	return 0;
}

sub messages {
	my ($self) = @_;

	if ( $self->{messages} ) {
		return @{ $self->{messages} };
	}
	return;
}

sub platform {
	my ($self) = @_;

	return $self->{new_platform} // $self->{platform};
}

sub polyline {
	my ($self) = @_;

	if ( $self->{polyline} ) {
		return @{ $self->{polyline} };
	}
	return;
}

sub route {
	my ($self) = @_;

	if ( $self->{route} ) {
		return @{ $self->{route} };
	}
	return;
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

sub type {
	my ($self) = @_;
	my $type;

	# $self->{train} is either "TYPE 12345" or "TYPE12345"
	if ( $self->{train} =~ m{ \s }x ) {
		($type) = ( $self->{train} =~ m{ ^ ([^[:space:]]+) }x );
	}
	else {
		($type) = ( $self->{train} =~ m{ ^ ([[:alpha:]]+) }x );
	}

	return $type;
}

sub line_no {
	my ($self) = @_;
	my $line_no;

	# $self->{train} is either "TYPE 12345" or "TYPE12345"
	if ( $self->{train} =~ m{ \s }x ) {
		($line_no) = ( $self->{train} =~ m{ ([^[:space:]]+) $ }x );
	}
	else {
		($line_no) = ( $self->{train} =~ m{ ([[:digit:]]+) $ }x );
	}

	return $line_no;
}

sub train_no {
	my ($self) = @_;

	return $self->line_no;
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Journey - Information about a single
arrival/departure received by Travel::Status::DE::HAFAS

=head1 SYNOPSIS

	for my $departure ($status->results) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->time,
			$departure->line,
			$departure->destination,
			$departure->platform,
		);
	}

	# or (depending on module setup)
	for my $arrival ($status->results) {
		printf(
			"At %s: %s from %s on platform %s\n",
			$arrival->time,
			$arrival->line,
			$arrival->origin,
			$arrival->platform,
		);
	}

=head1 VERSION

version 3.01

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Journey describes a single arrival/departure
as obtained by Travel::Status::DE::HAFAS.  It contains information about
the platform, time, route and more.

=head1 METHODS

=head2 ACCESSORS

=over

=item $result->countdown

Difference between the time Travel::Status::DE::HAFAS->results
was called first and the arrival/departure time, in minutes.

=item $result->countdown_sec

Difference between the time Travel::Status::DE::HAFAS->results
was called first and the arrival/departure time, in seconds.

=item $result->date

Arrival/Departure date in "dd.mm.yyyy" format.

=item $result->datetime

DateTime object holding the arrival/departure date and time.

=item $result->delay

Returns the delay in minutes, or undef if it is unknown.
Also returns undef if the arrival/departure has been cancelled.

=item $result->info

Returns additional information, for instance the most recent delay reason.
undef if no (useful) information is available.

=item $result->is_cancelled

True if the arrival/departure was cancelled, false otherwise.

=item $result->is_changed_platform

True if the platform (as returned by the B<platform> accessor) is not the
scheduled one. Note that the scheduled platform is unknown in this case.

=item $result->messages

Returns a list of message strings related to this result. Messages usually are
service notices (e.g. "missing carriage") or detailed delay reasons
(e.g. "switch damage between X and Y, expect delays").

=item $result->line

=item $result->train

Returns the line name, either in a format like "Bus SB16" (Bus line SB16)
or "RE 10111" (RegionalExpress train 10111, no line information).
May contain extraneous whitespace characters.

=item $result->line_no

=item $result->train_no

Returns the line/train number, for instance "SB16" (bus line SB16),
"11" (Underground train line U 11) or 1011 ("RegionalExpress train 1011").
Note that this may not be a number at all: Some transport services also
use single-letter characters or words (e.g. "AIR") as line numbers.

=item $result->operator

Returns the operator responsible for this arrival/departure. Returns undef
if the backend does not provide an operator.

Note that E<Ouml>BB is the only known backend providing this information.

=item $result->platform

Returns the arrival/departure platform.
Realtime data if available, schedule data otherwise.

=item $result->route_end

=item $result->destination

=item $result->origin

Returns the last element of the route.  Depending on how you set up
Travel::Status::DE::HAFAS (arrival or departure listing), this is
either the result's destination or its origin station.

=item $result->sched_date

Scheduled arrival/departure date in "dd.mm.yyyy" format.

=item $result->sched_datetime

DateTime object holding the scheduled arrival/departure date and time.

=item $result->sched_time

Scheduled arrival/departure time in "hh:mm" format.

=item $result->time

Arrival/Departure time in "hh:mm" format.

=item $result->type

Returns the type of this result, e.g. "S" for S-Bahn, "RE" for Regional Express
or "STR" for tram / StraE<szlig>enbahn.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Status::DE::HAFAS(3pm).

=head1 AUTHOR

Copyright (C) 2015-2020 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
