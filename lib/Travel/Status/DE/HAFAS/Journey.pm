package Travel::Status::DE::HAFAS::Journey;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use parent 'Class::Accessor';

our $VERSION = '3.01';

Travel::Status::DE::HAFAS::Journey->mk_ro_accessors(
	qw(datetime sched_datetime rt_datetime is_cancelled operator delay
	  platform sched_platform rt_platform
	  train route_end route_start origin destination direction)
);

# {{{ Constructor

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

	my $direction    = $journey->{dirTxt};
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
				lon       => $loc->{crd}{x} * 1e-6,
				lat       => $loc->{crd}{y} * 1e-6,
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
		direction    => $direction,
		route_end    => $stops[-1]{name},
		messages     => \@messages,
		route        => \@stops,
	};

	if ( $journey->{stbStop} ) {
		if ( $hafas->{arrivals} ) {
			$ref->{origin} = $ref->{route_end};
		}
		else {
			$ref->{destination} = $ref->{route_end};
		}
	}
	else {
		$ref->{route_start} = $stops[0]{name};
	}

	bless( $ref, $obj );

	if ( $journey->{stbStop} ) {
		$ref->{sched_platform} = $journey->{stbStop}{dPlatfS};
		$ref->{rt_platform}    = $journey->{stbStop}{dPlatfR};
		$ref->{platform}       = $ref->{rt_platform} // $ref->{sched_platform};

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
	}
	if ( $opt{polyline} ) {
		$ref->{polyline} = $opt{polyline};
	}

	return $ref;
}

# }}}

# {{{ Accessors

sub line {
	my ($self) = @_;

	return $self->{train};
}

sub is_changed_platform {
	my ($self) = @_;

	if ( defined $self->{rt_platform} and defined $self->{sched_platform} ) {
		if ( $self->{rt_platform} ne $self->{sched_platform} ) {
			return 1;
		}
		return 0;
	}
	if ( defined $self->{rt_platform} ) {
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

	my $ret = { %{$self} };

	for my $k ( keys %{$ret} ) {
		if ( ref( $ret->{$k} ) eq 'DateTime' ) {
			$ret->{$k} = $ret->{$k}->epoch;
		}
	}

	for my $stop ( @{ $ret->{route} } ) {
		for my $k ( keys %{$stop} ) {
			if ( ref( $stop->{$k} ) eq 'DateTime' ) {
				$stop->{$k} = $stop->{$k}->epoch;
			}
		}
	}

	return $ret;
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

# }}}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Journey - Information about a single
journey received by Travel::Status::DE::HAFAS

=head1 SYNOPSIS

	for my $departure ($status->results) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->datetime->strftime('%H:%M'),
			$departure->line,
			$departure->destination,
			$departure->platform,
		);
	}

	# or (depending on module setup)
	for my $arrival ($status->results) {
		printf(
			"At %s: %s from %s on platform %s\n",
			$arrival->datetime->strftime('%H:%M'),
			$arrival->line,
			$arrival->origin,
			$arrival->platform,
		);
	}

=head1 VERSION

version 3.01

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Journey describes a single journey. It is either
a station-specific arrival/departure obtained by a stationboard query, or a
train journey that does not belong to a specific station.

stationboard-specific accessors are annotated with "(station only)" and return
undef for non-station results.

=head1 METHODS

=head2 ACCESSORS

=over

=item $result->rt_datetime (station only)

DateTime object indicating the actual arrival/departure date and time.
undef if no real-time data is available.

=item $result->sched_datetime (station only)

DateTime object indicating the scheduled arrival/departure date and time.
undef if no schedule data is available.

=item $result->datetime (station only)

DateTime object indicating the arrival/departure date and time.
Real-time data if available, schedule data otherwise.
undef if neither is available.

=item $result->delay (station only)

Returns the delay in minutes, or undef if it is unknown.
Also returns undef if the arrival/departure has been cancelled.

=item $result->is_cancelled

True if the journey was cancelled, false otherwise.

=item $result->rt_platform (station only)

Actual arrival/departure platform.
undef if no real-time data is available.

=item $result->sched_platform (station only)

Scheduled arrival/departure platform.
undef if no scheduled platform is available.

=item $result->platform (station only)

Arrival/Departure platform. Real-time data if available, schedule data
otherwise. May be undef.

=item $result->is_changed_platform (station only)

True if the real-time platform is known and it is not the scheduled one.

=item $result->messages

Returns a list of message strings related to this result. Messages usually are
service notices (e.g. "missing carriage") or detailed delay reasons
(e.g. "switch damage between X and Y, expect delays").

=item $result->line

=item $result->train

Returns the line name, either in a format like "Bus SB16" (Bus line SB16)
or "RE 10111" (RegionalExpress train 10111, no line information).
May contain extraneous whitespace characters.

=item $result->type

Returns the type of this result, e.g. "S" for S-Bahn, "RE" for Regional Express
or "STR" for tram / StraE<szlig>enbahn.

=item $result->line_no

=item $result->train_no

Returns the line/train number, for instance "SB16" (bus line SB16),
"11" (Underground train line U 11) or 1011 ("RegionalExpress train 1011").
Note that this may not be a number at all: Some transport services also
use single-letter characters or words (e.g. "AIR") as line numbers.

=item $result->operator

Returns the operator responsible for this journey. Returns undef
if the backend does not provide an operator.

Note that E<Ouml>BB is the only known backend providing this information.

=item $result->route

Returns a list of hashes; each hash describes a single journey stop.
In stationboard mode, it only contains arrivals prior to the requested station
or departures after the requested station. In journey mode, it contains the
entire route. Each hash contains the following keys:

=over

=item * name (name

=item * eva (EVA ID)

=item * lon (longitude)

=item * lat (latitude)

=item * rt_arr (DateTime object for actual arrival)

=item * sched_arr (DateTime object for scheduled arrival)

=item * arr (DateTime object for actual or scheduled arrival)

=item * arr_delay (arrival delay in minutes)

=item = rt_dep (DateTime object for actual departure)

=item * sched_dep (DateTime object for scheduled departure)

=item * dep (DateTIme object for actual or scheduled departure)

=item * dep_delay (departure delay in minutes)

=item * delay (departure or arrival delay in minutes)

=back

Individual entries may be undef.

=item $result->route_end

Name of the last route station. In arrival mode, this is where the train
started; in all other cases, it is the terminus.

=item $result->destination

Alias for route_end; only set when requesting departures in station mode.

=item $result->origin

Alias for route_end; only set when requesting arrivals in station mode.

=item $result->direction

Train direction; this is typically the text printed on the train itself.
May be different from destination / route_end and may change along the route.

=item $result->polyline (journey only)

List of geocoordinates that describe the train's route. Each list entry is
a hash with the following keys.

=over

=item * lon (longitude)

=item * lat (latitude)

=item * name (name of stop at this location, if any. undef otherwise)

=item * eva (EVA ID of stop at this location, if any. undef otherwise)

=back

Note that stop locations in B<polyline> may differ from the coordinates
returned in B<route>. This is a backend issue; Travel::Status::DE::HAFAS
simply passes the returned coordinates on.

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

Copyright (C) 2015-2022 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
