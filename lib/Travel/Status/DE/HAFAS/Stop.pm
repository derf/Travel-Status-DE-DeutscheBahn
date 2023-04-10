package Travel::Status::DE::HAFAS::Stop;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '4.09';

Travel::Status::DE::HAFAS::Stop->mk_ro_accessors(
	qw(eva name lat lon distance_m weight));

# {{{ Constructor

sub new {
	my ( $obj, %opt ) = @_;

	my $loc = $opt{loc};
	my $ref = {
		eva        => 0 + $loc->{extId},
		name       => $loc->{name},
		lat        => $loc->{crd}{x} * 1e-6,
		lon        => $loc->{crd}{y} * 1e-6,
		weight     => $loc->{wt},
		distance_m => $loc->{dist},
	};

	bless( $ref, $obj );

	return $ref;
}

# }}}

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

version 4.09

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Stop describes a HAFAS stop. It may be part of a
journey or part of a geoSearch / locationSearch request.

geoSearch- and locationSearch-specific accessors are annotated accordingly and
return undef for non-geoSearch / non-locationSearch stops.

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

Copyright (C) 2023 by Birthe Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
