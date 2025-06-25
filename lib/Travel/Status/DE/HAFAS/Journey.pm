package Travel::Status::DE::HAFAS::Journey;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';
use DateTime::Format::Strptime;
use List::Util qw(any uniq);
use Travel::Status::DE::HAFAS::Stop;

our $VERSION = '6.21';

Travel::Status::DE::HAFAS::Journey->mk_ro_accessors(
	qw(datetime sched_datetime rt_datetime tz_offset
	  is_additional is_cancelled is_partially_cancelled
	  station station_eva platform sched_platform rt_platform operator
	  product product_at
	  id name type type_long class number line line_no load delay
	  route_end route_start origin destination direction)
);

# {{{ Constructor

sub new {
	my ( $obj, %opt ) = @_;

	my @icoL  = @{ $opt{common}{icoL}  // [] };
	my @tcocL = @{ $opt{common}{tcocL} // [] };
	my @remL  = @{ $opt{common}{remL}  // [] };
	my @himL  = @{ $opt{common}{himL}  // [] };

	my $prodL   = $opt{prodL};
	my $locL    = $opt{locL};
	my $hafas   = $opt{hafas};
	my $journey = $opt{journey};

	my $date = $opt{date} // $journey->{date};

	my $direction = $journey->{dirTxt};
	my $jid       = $journey->{jid};

	my $is_cancelled        = $journey->{isCncl};
	my $partially_cancelled = $journey->{isPartCncl};

	my $product = $prodL->[ $journey->{prodX} ];

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

	my $datetime_ref;

	if ( @{ $journey->{stopL} // [] } or $journey->{stbStop} ) {
		my ( $date_ref, $parse_fmt );
		if ( $jid =~ /#/ ) {

			# modern trip ID, used e.g. by DB and ÖBB
			$date_ref  = ( split( /#/, $jid ) )[12];
			$parse_fmt = '%d%m%y';
			if ( length($date_ref) < 5 ) {
				warn(
"HAFAS, not even once -- midnight crossing may be bogus -- date_ref $date_ref"
				);
			}
			elsif ( length($date_ref) == 5 ) {
				$date_ref = "0${date_ref}";
			}
		}
		else {
			# old (legacy?) trip ID
			$date_ref  = ( split( qr{[|]}, $jid ) )[4];
			$parse_fmt = '%d%m%Y';
			if ( length($date_ref) < 7 ) {
				warn(
"HAFAS, not even once -- midnight crossing may be bogus -- date_ref $date_ref"
				);
			}
			elsif ( length($date_ref) == 7 ) {
				$date_ref = "0${date_ref}";
			}
		}
		$datetime_ref = DateTime::Format::Strptime->new(
			pattern   => $parse_fmt,
			time_zone => $hafas->get_active_service->{time_zone}
			  // 'Europe/Berlin'
		)->parse_datetime($date_ref);
	}

	my @stops;
	my $route_end;
	for my $stop ( @{ $journey->{stopL} // [] } ) {
		my $loc = $locL->[ $stop->{locX} ];

		my $stopref = {
			loc          => $loc,
			stop         => $stop,
			common       => $opt{common},
			prodL        => $prodL,
			hafas        => $hafas,
			date         => $date,
			datetime_ref => $datetime_ref,
		};

		push( @stops, $stopref );

		$route_end = $loc->name;
	}

	if ( $journey->{stbStop} ) {
		if ( $hafas->{arrivals} ) {
			$route_end = $stops[0]->{name};
			pop(@stops);
		}
		else {
			shift(@stops);
		}
	}

	my $ref = {
		id                     => $jid,
		product                => $product,
		name                   => $product->name,
		number                 => $product->number,
		line                   => $product->name,
		line_no                => $product->line_no,
		type                   => $product->type,
		type_long              => $product->type_long,
		class                  => $product->class,
		operator               => $product->operator,
		direction              => $direction,
		is_cancelled           => $is_cancelled,
		is_partially_cancelled => $partially_cancelled,
		route_end              => $route_end // $direction,
		messages               => \@messages,
		route                  => \@stops,
	};

	if ( $journey->{stbStop} ) {
		if ( $hafas->{arrivals} ) {
			$ref->{origin} = $ref->{route_end};
			$ref->{is_cancelled} ||= $journey->{stbStop}{aCncl};
		}
		else {
			$ref->{destination} = $ref->{route_end};
			$ref->{is_cancelled} ||= $journey->{stbStop}{dCncl};
		}
		$ref->{is_additional} = $journey->{stbStop}{isAdd};
	}
	elsif ( $stops[0] and $stops[0]{loc} ) {
		$ref->{route_start} = $stops[0]{loc}->name;
	}

	bless( $ref, $obj );

	if ( $journey->{stbStop} ) {
		$ref->{station}        = $locL->[ $journey->{stbStop}{locX} ]->name;
		$ref->{station_eva}    = 0 + $locL->[ $journey->{stbStop}{locX} ]->eva;
		$ref->{sched_platform} = $journey->{stbStop}{dPlatfS}
		  // $journey->{stbStop}{dPltfS}{txt};
		$ref->{rt_platform} = $journey->{stbStop}{dPlatfR}
		  // $journey->{stbStop}{dPltfR}{txt};
		$ref->{platform} = $ref->{rt_platform} // $ref->{sched_platform};

		my $datetime_s = Travel::Status::DE::HAFAS::Stop::handle_day_change(
			$ref,
			input =>
			  $journey->{stbStop}{ $hafas->{arrivals} ? 'aTimeS' : 'dTimeS' },
			offset => $journey->{stbStop}{
				$hafas->{arrivals}
				? 'aTZOffset'
				: 'dTZOffset'
			},
			date     => $date,
			strp_obj => $hafas->{strptime_obj},
			ref      => $datetime_ref,
		);

		my $datetime_r = Travel::Status::DE::HAFAS::Stop::handle_day_change(
			$ref,
			input =>
			  $journey->{stbStop}{ $hafas->{arrivals} ? 'aTimeR' : 'dTimeR' },
			offset => $journey->{stbStop}{
				$hafas->{arrivals}
				? 'aTZOffset'
				: 'dTZOffset'
			},
			date     => $date,
			strp_obj => $hafas->{strptime_obj},
			ref      => $datetime_ref,
		);

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

		my %tco;
		for my $tco_id ( @{ $journey->{stbStop}{dTrnCmpSX}{tcocX} // [] } ) {
			my $tco_kv = $tcocL[$tco_id];

			# BVG has rRT (real-time?) and r (prognosed?); others only have r
			my $load = $tco_kv->{rRT} // $tco_kv->{r};

			# BVG uses 11 .. 13 rather than 1 .. 4
			if ( defined $load and $load > 10 ) {
				$load -= 10;
			}

			$tco{ $tco_kv->{c} } = $load;
		}
		if (%tco) {
			$ref->{load} = \%tco;
		}
	}
	if ( $opt{polyline} ) {
		$ref->{polyline} = $opt{polyline};
	}

	return $ref;
}

# }}}

# {{{ Accessors

# Legacy
sub station_uic {
	my ($self) = @_;
	return $self->{station_eva};
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

sub operators {
	my ($self) = @_;

	if ( $self->{operators} ) {
		return @{ $self->{operators} };
	}

	$self->{operators} = [
		uniq map { ( $_->prod_arr // $_->prod_dep )->operator } grep {
			      ( $_->prod_arr or $_->prod_dep )
			  and ( $_->prod_arr // $_->prod_dep )->operator
		} $self->route
	];

	return @{ $self->{operators} };
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

	if ( $self->{route} and @{ $self->{route} } ) {
		if ( $self->{route}[0] and $self->{route}[0]{stop} ) {
			$self->{route}
			  = [ map { Travel::Status::DE::HAFAS::Stop->new( %{$_} ) }
				  @{ $self->{route} } ];
		}
		return @{ $self->{route} };
	}
	return;
}

sub route_interesting {
	my ( $self, $max_parts ) = @_;

	my @via = $self->route;
	my ( @via_main, @via_show, $last_stop );
	$max_parts //= 3;

	# Centraal: dutch main station (Hbf in .nl)
	# HB:  swiss main station (Hbf in .ch)
	# hl.n.: czech main station (Hbf in .cz)
	for my $stop (@via) {
		if ( $stop->loc->name
			=~ m{ HB $ | hl\.n\. $ | Hbf | Hauptbahnhof | Bf | Bahnhof | Centraal | Flughafen }x
		  )
		{
			push( @via_main, $stop );
		}
	}
	$last_stop = pop(@via);

	if ( @via_main and $via_main[-1]->loc->name eq $last_stop->loc->name ) {
		pop(@via_main);
	}
	if ( @via and $via[-1]->loc->name eq $last_stop->loc->name ) {
		pop(@via);
	}

	if ( @via_main and @via and $via[0]->loc->name eq $via_main[0]->loc->name )
	{
		shift(@via_main);
	}

	if ( @via < $max_parts ) {
		@via_show = @via;
	}
	else {
		if ( @via_main >= $max_parts ) {
			@via_show = ( $via[0] );
		}
		else {
			@via_show = splice( @via, 0, $max_parts - @via_main );
		}

		while ( @via_show < $max_parts and @via_main ) {
			my $stop = shift(@via_main);
			if ( any { $_->loc->name eq $stop->loc->name } @via_show
				or $stop->loc->name eq $last_stop->loc->name )
			{
				next;
			}
			push( @via_show, $stop );
		}
	}

	return @via_show;

}

sub product_at {
	my ( $self, $req_stop ) = @_;
	for my $stop ( $self->route ) {
		if ( $stop->loc->name eq $req_stop or $stop->loc->eva eq $req_stop ) {
			return $stop->prod_dep // $stop->prod_arr;
		}
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
	$ret->{route} = [ map { $_->TO_JSON } $self->route ];

	return $ret;
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

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Journey describes a single journey. It is either
a station-specific arrival/departure obtained by a stationboard query, or a
train journey that does not belong to a specific station.

stationboard-specific accessors are annotated with "(station only)" and return
undef for non-station journeys. All date and time entries refer to the
backend time zone (Europe/Berlin in most cases) and do not take local time
into account; see B<tz_offset> for the latter.

=head1 METHODS

=head2 ACCESSORS

=over

=item $journey->name

Journey or line name, either in a format like "Bus SB16" (Bus line
SB16) or "RE 10111" (RegionalExpress train 10111, no line information).  May
contain extraneous whitespace characters.

=item $journey->type

Type of this journey, e.g. "S" for S-Bahn, "RE" for Regional Express
or "STR" for tram / StraE<szlig>enbahn.

=item $journey->type_long

Long type of this journey, e.g. "S-Bahn" or "Regional-Express".

=item $journey->class

An integer identifying the the mode of transport class.
Semantics depend on backend, e.g. "1" and "2" for long-distance trains and
"4" and "8" for regional trains.

=item $journey->line

Journey or line name, either in a format like "Bus SB16" (Bus line
SB16), "RE 42" (RegionalExpress train 42) or "IC 2901" (InterCity train 2901,
no line information).  May contain extraneous whitespace characters.  Note that
this accessor does not return line information for IC/ICE/EC services, even if
it is available. Use B<line_no> for those.

=item $journey->line_no

Line identifier, or undef if it is unknown.
The line identifier may be a single number such as "11" (underground train
line U 11), a single word (e.g. "AIR") or a combination (e.g. "SB16").
May also provide line numbers of IC/ICE services.

=item $journey->number

Journey number (e.g. train number), or undef if it is unknown.

=item $journey->id

HAFAS-internal journey ID.

=item $journey->rt_datetime (station only)

DateTime object indicating the actual arrival/departure date and time.
undef if no real-time data is available.

=item $journey->sched_datetime (station only)

DateTime object indicating the scheduled arrival/departure date and time.
undef if no schedule data is available.

=item $journey->datetime (station only)

DateTime object indicating the arrival/departure date and time.
Real-time data if available, schedule data otherwise.
undef if neither is available.

=item $journey->tz_offset

Offset between backend time zone (default: Europe/Berlin) and this journey's
time zone in minutes, if any. For instance, if the backend uses UTC+2 (CEST)
and the journey uses UTC+1 (IST), tz_offset is -60. Returns undef if both use
the same time zone (or rather, the same UTC offset).

=item $journey->delay (station only)

Delay in minutes, or undef if it is unknown.
Also returns undef if the arrival/departure has been cancelled.

=item $journey->is_additional (station only)

True if the journey's stop at the requested station is an unscheduled addition
to its route.

=item $journey->is_cancelled

True if the journey was cancelled, false otherwise.

=item $journey->is_partially_cancelled

True if part of the journey was cancelled, false otherwise.

=item $journey->product

Travel::Status::DE::HAFAS::Product(3pm) instance describing the product (mode
of transport, line number / ID, operator, ...) associated with this journey.
Note that journeys may be associated with multiple products -- see also
C<< $journey->route >> and C<< $stop->product >>.

=item $journey->product_at(I<stop>)

Travel::Status::DE::HAFAS::Product(3pm) instance describing the product
associated with I<stop> (name or EVA ID). Returns undef if product or I<stop>
are unknown.

=item $journey->rt_platform (station only)

Actual arrival/departure platform.
undef if no real-time data is available.

=item $journey->sched_platform (station only)

Scheduled arrival/departure platform.
undef if no scheduled platform is available.

=item $journey->platform (station only)

Arrival/Departure platform. Real-time data if available, schedule data
otherwise. May be undef.

=item $journey->is_changed_platform (station only)

True if the real-time platform is known and it is not the scheduled one.

=item $journey->load (station only)

Expected passenger load (i.e., how full the vehicle is) at the requested stop.
If known, returns a hashref that maps classes (typically FIRST/SECOND) to
load estimation numbers. The DB backend uses 1 (low to medium), 2 (high),
3 (very high), and 4 (exceptionally high, train is booked out).
Undef if unknown.

=item $journey->messages

List of Travel::Status::DE::HAFAS::Message(3pm) instances related to this
journey. Messages usually are service notices (e.g. "missing carriage") or
detailed delay reasons (e.g. "switch damage between X and Y, expect delays").

=item $journey->operator

The operator responsible for this journey. Returns undef
if the backend does not provide an operator. Note that the operator may
change along the journey -- in this case, the returned operator depends on
the backend and appears to be the first one in most cases.

=item $journey->operators

List of all operators observed along the journey.

=item $journey->station (station only)

Name of the station at which this journey was requested.

=item $journey->station_eva (station only)

UIC/EVA ID of the station at which this journey was requested.

=item $journey->route

List of Travel::Status::DE::HAFAS::Stop(3pm) objects that describe individual
stops along the journey. In stationboard mode, the list only contains arrivals
prior to the requested station or departures after the requested station. In
journey mode, it contains the entire route.

=item $journey->route_interesting([I<count>])

Up to I<count> (default: B<3>) parts of C<< $journey->route >> that may
be particularly helpful, e.g. main stations or airports.

=item $journey->route_end

Name of the last route station. In arrival mode, this is where the train
started; in all other cases, it is the terminus.

=item $journey->destination

Alias for route_end; only set when requesting departures in station mode.

=item $journey->origin

Alias for route_end; only set when requesting arrivals in station mode.

=item $journey->direction

Train direction; this is typically the text printed on the train itself.
May be different from destination / route_end and may change along the route,
see above.

=item $journey->polyline (journey only)

List of geocoordinates that describe the train's route. Only available if the
HAFAS object constructor was passed a true B<with_polyline> value.  Each list
entry is a hash with the following keys.

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

Copyright (C) 2015-2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
