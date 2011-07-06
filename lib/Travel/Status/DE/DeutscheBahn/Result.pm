package Travel::Status::DE::DeutscheBahn::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.02';

Travel::Status::DE::DeutscheBahn::Result->mk_ro_accessors(
	qw(time train route_end route_raw platform info));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub destination {
	my ($self) = @_;

	return $self->{route_end};
}

sub origin {
	my ($self) = @_;

	return $self->{route_end};
}

sub route {
	my ($self) = @_;

	return @{ $self->{route} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::DeutscheBahn::Result - Information about a single
arrival/departure received by Travel::Status::DE::DeutscheBahn

=head1 SYNOPSIS

	for my $departure ($status->results) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->time,
			$departure->train,
			$departure->destination,
			$departure->platform,
		);
	}

	# or (depending on module setup)
	for my $arrival ($status->results) {
		printf(
			"At %s: %s from %s on platform %s\n",
			$arrival->time,
			$arrival->train,
			$arrival->origin,
			$arrival->platform,
		);
	}

=head1 VERSION

version 0.02

=head1 DESCRIPTION

Travel::Status::DE::DeutscheBahn::Result describes a single arrival/departure
as obtained by Travel::Status::DE::DeutscheBahn.  It contains information about
the platform, time, route and more.

=head1 METHODS

=head2 ACCESSORS

=over

=item $result->route_end

Returns the last element of the route.  Depending on how you set up
Travel::Status::DE::DeutscheBahn (arrival or departure listing), this is
either the train's destination or its origin station.

=item $result->destination

=item $result->origin

Convenience aliases for $result->route_end.

=item $result->info

Returns additional information, usually wether the train is on time or
delayed.

=item $result->platform

Returns the platform from which the train will depart / at which it will
arrive.

=item $result->route

Returns a list of station names the train will pass between the selected
station and its origin/destination.

=item $result->route_raw

Returns the raw string used to create the route array.

Note that canceled stops are filtered from B<route>, but still present in
B<route_raw>.

=item $result->time

Returns the arrival/departure time as string in "hh:mm" format.

=item $result->train

Returns the line / train name, either in a format like "S 1" (S-Bahn line 1)
or "RE 10111" (RegionalExpress train 10111, no line information).

=back

=head2 INTERNAL

=over

=item $result = Travel::Status::DE::DeutscheBahn::Result->new(I<%data>)

Returns a new Travel::Status::DE::DeutscheBahn::Result object.
You usually do not need to call this.

Required I<data>:

=over

=item B<time> => I<hh:mm>

=item B<train> => I<string>

=item B<route_raw> => I<string>

=item B<route> => I<arrayref>

=item B<route_end> => I<string>

=item B<platform> => I<string>

=item B<info> => I<string>

=back

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

Unknown.

=head1 SEE ALSO

Travel::Status::DE::DeutscheBahn(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
