package Travel::Status::DE::HAFAS::Stop;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '6.21';

Travel::Status::DE::HAFAS::Stop->mk_ro_accessors(
	qw(loc
	  rt_arr sched_arr arr arr_delay arr_cancelled prod_arr
	  rt_dep sched_dep dep dep_delay dep_cancelled prod_dep
	  delay direction
	  rt_platform sched_platform platform is_changed_platform
	  is_additional tz_offset
	  load
	)
);

# {{{ Constructor

sub new {
	my ( $obj, %opt ) = @_;

	my $stop         = $opt{stop};
	my $common       = $opt{common};
	my $prodL        = $opt{prodL};
	my $date         = $opt{date};
	my $datetime_ref = $opt{datetime_ref};
	my $hafas        = $opt{hafas};
	my $strp_obj     = $opt{hafas}{strptime_obj};

	my $prod_arr
	  = defined $stop->{aProdX} ? $prodL->[ $stop->{aProdX} ] : undef;
	my $prod_dep
	  = defined $stop->{dProdX} ? $prodL->[ $stop->{dProdX} ] : undef;

	# dIn. / aOut. -> may passengers enter / exit the train?

	my $sched_platform = $stop->{aPlatfS} // $stop->{dPlatfS}
	  // $stop->{aPltfS}{txt} // $stop->{dPltfS}{txt};
	my $rt_platform = $stop->{aPlatfR} // $stop->{dPlatfR}
	  // $stop->{aPltfR}{txt} // $stop->{dPltfR}{txt};
	my $changed_platform = $stop->{aPlatfCh} // $stop->{dPlatfCh};

	my $arr_cancelled = $stop->{aCncl};
	my $dep_cancelled = $stop->{dCncl};
	my $is_additional = $stop->{isAdd};

	my $ref = {
		loc                 => $opt{loc},
		direction           => $stop->{dDirTxt},
		sched_platform      => $sched_platform,
		rt_platform         => $rt_platform,
		is_changed_platform => $changed_platform,
		platform            => $rt_platform // $sched_platform,
		arr_cancelled       => $arr_cancelled,
		dep_cancelled       => $dep_cancelled,
		is_additional       => $is_additional,
		prod_arr            => $prod_arr,
		prod_dep            => $prod_dep,
	};

	bless( $ref, $obj );

	my $sched_arr = $ref->handle_day_change(
		input    => $stop->{aTimeS},
		offset   => $stop->{aTZOffset},
		date     => $date,
		strp_obj => $strp_obj,
		ref      => $datetime_ref
	);

	my $rt_arr = $ref->handle_day_change(
		input    => $stop->{aTimeR},
		offset   => $stop->{aTZOffset},
		date     => $date,
		strp_obj => $strp_obj,
		ref      => $datetime_ref
	);

	my $sched_dep = $ref->handle_day_change(
		input    => $stop->{dTimeS},
		offset   => $stop->{dTZOffset},
		date     => $date,
		strp_obj => $strp_obj,
		ref      => $datetime_ref
	);

	my $rt_dep = $ref->handle_day_change(
		input    => $stop->{dTimeR},
		offset   => $stop->{dTZOffset},
		date     => $date,
		strp_obj => $strp_obj,
		ref      => $datetime_ref
	);

	$ref->{arr_delay}
	  = ( $sched_arr and $rt_arr )
	  ? ( $rt_arr->epoch - $sched_arr->epoch ) / 60
	  : undef;

	$ref->{dep_delay}
	  = ( $sched_dep and $rt_dep )
	  ? ( $rt_dep->epoch - $sched_dep->epoch ) / 60
	  : undef;

	$ref->{delay} = $ref->{dep_delay} // $ref->{arr_delay};

	$ref->{sched_arr} = $sched_arr;
	$ref->{sched_dep} = $sched_dep;
	$ref->{rt_arr}    = $rt_arr;
	$ref->{rt_dep}    = $rt_dep;
	$ref->{arr}       = $rt_arr // $sched_arr;
	$ref->{dep}       = $rt_dep // $sched_dep;

	my @messages;
	for my $msg ( @{ $stop->{msgL} // [] } ) {
		if ( $msg->{type} eq 'REM' and defined $msg->{remX} ) {
			push( @messages,
				$hafas->add_message( $opt{common}{remL}[ $msg->{remX} ] ) );
		}
		elsif ( $msg->{type} eq 'HIM' and defined $msg->{himX} ) {
			push( @messages,
				$hafas->add_message( $opt{common}{himL}[ $msg->{himX} ], 1 ) );
		}
		else {
			say "Unknown message type $msg->{type}";
		}
	}
	$ref->{messages} = \@messages;

	$ref->{load} = {};
	for my $tco_id ( @{ $stop->{dTrnCmpSX}{tcocX} // [] } ) {
		my $tco_kv = $common->{tcocL}[$tco_id];

		# BVG has rRT (real-time?) and r (prognosed?); others only have r
		my $load = $tco_kv->{rRT} // $tco_kv->{r};

		# BVG uses 11 .. 13 rather than 1 .. 4
		if ( defined $load and $load > 10 ) {
			$load -= 10;
		}

		$ref->{load}{ $tco_kv->{c} } = $load;
	}

	return $ref;
}

# }}}

sub handle_day_change {
	my ( $self, %opt ) = @_;
	my $date    = $opt{date};
	my $timestr = $opt{input};
	my $offset  = $opt{offset};

	if ( not defined $timestr ) {
		return;
	}

	if ( length($timestr) == 8 ) {

		# arrival time includes a day offset
		my $offset_date = $opt{ref}->clone;
		$offset_date->add( days => substr( $timestr, 0, 2, q{} ) );
		$offset_date = $offset_date->strftime('%Y%m%d');
		$timestr = $opt{strp_obj}->parse_datetime("${offset_date}T${timestr}");
	}
	else {
		$timestr = $opt{strp_obj}->parse_datetime("${date}T${timestr}");
	}

	if ( defined $offset and $offset != $timestr->offset / 60 ) {
		$self->{tz_offset} = $offset - $timestr->offset / 60;
		$timestr->subtract( minutes => $self->{tz_offset} );
	}

	return $timestr;
}

sub messages {
	my ($self) = @_;

	if ( $self->{messages} ) {
		return @{ $self->{messages} };
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

	return $ret;
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Stop - Information about a HAFAS stop.

=head1 SYNOPSIS

	# in journey mode
	for my $stop ($journey->route) {
		printf(
			%5s -> %5s %s\n",
			$stop->arr ? $stop->arr->strftime('%H:%M') : '--:--',
			$stop->dep ? $stop->dep->strftime('%H:%M') : '--:--',
			$stop->loc->name
		);
	}

=head1 VERSION

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Stop describes a
Travel::Status::DE::HAFAS::Journey(3pm)'s stop at a given
Travel::Status::DE::HAFAS::Location(3pm) with arrival/departure time,
platform, etc.

All date and time entries refer to the backend time zone (Europe/Berlin in most
cases) and do not take local time into account; see B<tz_offset> for the
latter.

=head1 METHODS

=head2 ACCESSORS

=over

=item $stop->loc

Travel::Status::DE::HAFAS::Location(3pm) instance describing stop name, EVA
ID, et cetera.

=item $stop->rt_arr

DateTime object for actual arrival.

=item $stop->sched_arr

DateTime object for scheduled arrival.

=item $stop->arr

DateTime object for actual or scheduled arrival.

=item $stop->arr_delay

Arrival delay in minutes.

=item $stop->arr_cancelled

Arrival is cancelled.

=item $stop->rt_dep

DateTime object for actual departure.

=item $stop->sched_dep

DateTime object for scheduled departure.

=item $stop->dep

DateTIme object for actual or scheduled departure.

=item $stop->dep_delay

Departure delay in minutes.

=item $stop->dep_cancelled

Departure is cancelled.

=item $stop->tz_offset

Offset between backend time zone (default: Europe/Berlin) and this stop's time
zone in minutes, if any. For instance, if the backend uses UTC+2 (CEST) and the
stop uses UTC+1 (IST), tz_offset is -60. Returns undef if both use the same
time zone (or rather, the same UTC offset).

=item $stop->delay

Departure or arrival delay in minutes.

=item $stop->direction

Direction signage from this stop on, undef if unchanged.

=item $stop->messages

List of Travel::Status::DE::HAFAS::Message(3pm) instances related to this stop.
These typically refer to delay reasons, platform changes, or changes in the
line number / direction heading.

=item $stop->prod_arr

Travel::Status::DE::HAFAS::Product(3pm) instance describing the transit product
(name, type, line number, operator, ...) upon arrival at this stop.

=item $stop->prod_dep

Travel::Status::DE::HAFAS::Product(3pm) instance describing the transit product
(name, type, line number, operator, ...) upon departure from this stop.

=item $stop->rt_platform

Actual platform.

=item $stop->sched_platform

Scheduled platform.

=item $stop->platform

Actual or scheduled platform.

=item $stop->is_changed_platform

True if real-time and scheduled platform disagree.

=item $stop->is_additional

True if the stop is an unscheduled addition to the train's route.

=item $stop->load

Expected utilization / passenger load from this stop on.

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

Copyright (C) 2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
