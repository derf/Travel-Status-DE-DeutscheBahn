package Travel::Status::DE::HAFAS::Location;

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '6.21';

Travel::Status::DE::HAFAS::Location->mk_ro_accessors(
	qw(lid type name eva state lat lon distance_m weight));

sub new {
	my ( $obj, %opt ) = @_;

	my $loc = $opt{loc};

	my $ref = {
		lid   => $loc->{lid},
		type  => $loc->{type},
		name  => $loc->{name},
		eva   => 0 + $loc->{extId},
		state => $loc->{state},
		lat   => $loc->{crd}{y} * 1e-6,
		lon   => $loc->{crd}{x} * 1e-6,

		# only for geosearch requests
		weight     => $loc->{wt},
		distance_m => $loc->{dist},
	};

	bless( $ref, $obj );

	return $ref;
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	return $ret;
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Location - A single public transit location

=head1 SYNOPSIS

	printf("Destination: %s  (%8d)\n", $location->name, $location->eva);

=head1 VERSION

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Location describes a HAFAS location that belongs to
a stop (e.g. on a journey's route) or has been returned as part of a
locationSearch or geoSearch request.

=head1 METHODS

=head2 ACCESSORS

=over

=item $location->name

Location name, e.g. "Essen Hbf" or "Unter den Linden/B75, Tostedt".

=item $location->eva

EVA ID, e.g. 8000080.

=item $location->lat

Location latitude (WGS-84)

=item $location->lon

Location longitude (WGS-84)

=item $location->distance_m (geoSearch)

Distance in meters between the requested coordinates and this location.

=item $location->weight (geoSearch, locationSearch)

Weight / Relevance / Importance of this location using an unknown metric.
Higher values indicate more relevant locations.

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

Travel::Routing::DE::HAFAS(3pm).

=head1 AUTHOR

Copyright (C) 2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
