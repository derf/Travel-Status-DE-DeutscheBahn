package Travel::Status::DE::HAFAS::Stop;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '4.19';

Travel::Status::DE::HAFAS::Stop->mk_ro_accessors(
	qw(loc
	  rt_arr sched_arr arr arr_delay arr_cancelled
	  rt_dep sched_dep dep dep_delay dep_cancelled
	  delay direction
	  rt_platform sched_platform platform is_changed_platform
	  load
	)
);

# {{{ Constructor

sub new {
	my ( $obj, %opt ) = @_;

	my $stop         = $opt{stop};
	my $common       = $opt{common};
	my $date         = $opt{date};
	my $datetime_ref = $opt{datetime_ref};
	my $strp_obj     = $opt{strp_obj};

	my $sched_arr = $stop->{aTimeS};
	my $rt_arr    = $stop->{aTimeR};
	my $sched_dep = $stop->{dTimeS};
	my $rt_dep    = $stop->{dTimeR};

	# dIn. / aOut. -> may passengers enter / exit the train?

	my $sched_platform   = $stop->{aPlatfS}  // $stop->{dPlatfS};
	my $rt_platform      = $stop->{aPlatfR}  // $stop->{dPlatfR};
	my $changed_platform = $stop->{aPlatfCh} // $stop->{dPlatfCh};

	for my $timestr ( $sched_arr, $rt_arr, $sched_dep, $rt_dep ) {
		if ( not defined $timestr ) {
			next;
		}

		$timestr = handle_day_change(
			input    => $timestr,
			date     => $date,
			strp_obj => $strp_obj,
			ref      => $datetime_ref
		);

	}

	my $arr_delay
	  = ( $sched_arr and $rt_arr )
	  ? ( $rt_arr->epoch - $sched_arr->epoch ) / 60
	  : undef;

	my $dep_delay
	  = ( $sched_dep and $rt_dep )
	  ? ( $rt_dep->epoch - $sched_dep->epoch ) / 60
	  : undef;

	my $arr_cancelled = $stop->{aCncl};
	my $dep_cancelled = $stop->{dCncl};

	my $tco = {};
	for my $tco_id ( @{ $stop->{dTrnCmpSX}{tcocX} // [] } ) {
		my $tco_kv = $common->{tcocL}[$tco_id];
		$tco->{ $tco_kv->{c} } = $tco_kv->{r};
	}

	my $ref = {
		loc                 => $opt{loc},
		sched_arr           => $sched_arr,
		rt_arr              => $rt_arr,
		arr                 => $rt_arr // $sched_arr,
		arr_delay           => $arr_delay,
		arr_cancelled       => $arr_cancelled,
		sched_dep           => $sched_dep,
		rt_dep              => $rt_dep,
		dep                 => $rt_dep // $sched_dep,
		dep_delay           => $dep_delay,
		dep_cancelled       => $dep_cancelled,
		delay               => $dep_delay // $arr_delay,
		direction           => $stop->{dDirTxt},
		sched_platform      => $sched_platform,
		rt_platform         => $rt_platform,
		is_changed_platform => $changed_platform,
		platform            => $rt_platform // $sched_platform,
		load                => $tco,
	};

	bless( $ref, $obj );

	return $ref;
}

# }}}

sub handle_day_change {
	my (%opt)   = @_;
	my $date    = $opt{date};
	my $timestr = $opt{input};
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
	return $timestr;
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

version 4.19

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Stop describes a
Travel::Status::DE::HAFAS::Journey(3pm)'s stop at a given
Travel::Status::DE::HAFAS::Location(3pm) with arrival/departure time,
platform, etc.

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

=item $stop->delay

Departure or arrival delay in minutes.

=item $stop->direction

Direction signage from this stop on, undef if unchanged.

=item $stop->rt_platform

Actual platform.

=item $stop->sched_platform

Scheduled platform.

=item $stop->platform

Actual or scheduled platform.

=item $stop->is_changed_platform

True if real-time and scheduled platform disagree.

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
