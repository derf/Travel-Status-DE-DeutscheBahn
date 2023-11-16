package Travel::Status::DE::HAFAS::Stop;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '4.19';

Travel::Status::DE::HAFAS::Stop->mk_ro_accessors(
	qw(eva name lat lon distance_m weight
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

	my $loc = $opt{loc};
	my $ref = {
		eva        => $loc->{extId} + 0,
		name       => $loc->{name},
		lat        => $loc->{crd}{y} * 1e-6,
		lon        => $loc->{crd}{x} * 1e-6,
		weight     => $loc->{wt},
		distance_m => $loc->{dist},
	};

	if ( $opt{extra} ) {
		while ( my ( $k, $v ) = each %{ $opt{extra} } ) {
			$ref->{$k} = $v;
		}
	}

	bless( $ref, $obj );

	if ( $opt{stop} ) {
		$ref->parse_stop( $opt{stop}, $opt{common}, $opt{date},
			$opt{datetime_ref}, $opt{strp_obj} );
	}

	return $ref;
}

sub parse_stop {
	my ( $self, $stop, $common, $date, $datetime_ref, $strp_obj ) = @_;

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

	$self->{sched_arr}           = $sched_arr;
	$self->{rt_arr}              = $rt_arr;
	$self->{arr}                 = $rt_arr // $sched_arr;
	$self->{arr_delay}           = $arr_delay;
	$self->{arr_cancelled}       = $arr_cancelled;
	$self->{sched_dep}           = $sched_dep;
	$self->{rt_dep}              = $rt_dep;
	$self->{dep}                 = $rt_dep // $sched_dep;
	$self->{dep_delay}           = $dep_delay;
	$self->{dep_cancelled}       = $dep_cancelled;
	$self->{delay}               = $dep_delay // $arr_delay;
	$self->{direction}           = $stop->{dDirTxt};
	$self->{sched_platform}      = $sched_platform;
	$self->{rt_platform}         = $rt_platform;
	$self->{is_changed_platform} = $changed_platform;
	$self->{platform}            = $rt_platform // $sched_platform;
	$self->{load}                = $tco;

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

	# in geoSearch mode
	for my $stop ($status->results) {
		printf(
			"%5.1f km  %8d  %s\n",
			$result->distance_m * 1e-3,
			$result->eva, $result->name
		);
	}

=head1 VERSION

version 4.19

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Stop describes a HAFAS stop. It may be part of a
journey or part of a geoSearch / locationSearch request.

Journey-, geoSearch- and locationSearch-specific accessors are annotated
accordingly and return undef in other contexts.

=head1 METHODS

=head2 ACCESSORS

=over

=item $stop->name

Stop name, e.g. "Essen Hbf" or "Unter den Linden/B75, Tostedt".

=item $stop->eva

EVA ID, e.g. 8000080.

=item $stop->lat

Stop latitude (WGS-84)

=item $stop->lon

Stop longitude (WGS-84)

=item $stop->distance_m (geoSearch)

Distance in meters between the requested coordinates and this stop.

=item $stop->weight

Weight / Relevance / Importance of this stop using an unknown metric.
Higher values indicate more relevant stops.

=item $stop->rt_arr (journey)

DateTime object for actual arrival.

=item $stop->sched_arr (journey)

DateTime object for scheduled arrival.

=item $stop->arr (journey)

DateTime object for actual or scheduled arrival.

=item $stop->arr_delay (journey)

Arrival delay in minutes.

=item $stop->arr_cancelled (journey)

Arrival is cancelled.

=item $stop->rt_dep (journey)

DateTime object for actual departure.

=item $stop->sched_dep (journey)

DateTime object for scheduled departure.

=item $stop->dep (journey)

DateTIme object for actual or scheduled departure.

=item $stop->dep_delay (journey)

Departure delay in minutes.

=item $stop->dep_cancelled (journey)

Departure is cancelled.

=item $stop->delay (journey)

Departure or arrival delay in minutes.

=item $stop->direction (journey)

Direction signage from this stop on, undef if unchanged.

=item $stop->rt_platform (journey)

Actual platform.

=item $stop->sched_platform (journey)

Scheduled platform.

=item $stop->platform (journey)

Actual or scheduled platform.

=item $stop->is_changed_platform (journey)

True if real-time and scheduled platform disagree.

=item $stop->load (journey)

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
