package Travel::Status::DE::DeutscheBahn::Departure;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.0';

Travel::Status::DE::DeutscheBahn::Departure->mk_ro_accessors(
	qw(time train destination platform info));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub route {
	my ($self) = @_;

	return @{ $self->{route} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::DeutscheBahn::Departure - Information about a single
departure received by Travel::Status::DE::DeutscheBahn

=head1 SYNOPSIS

	for my $departure ($status->departures) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->time,
			$departure->train,
			$departure->destination,
			$departure->platform,
		);
	}

=head1 VERSION

version 0.0

=head1 DESCRIPTION

Travel::Status::DE::DeutscheBahn::Departure describes a single departure as
obtained by Travel::Status::DE::DeutscheBahn. It contains information about
the platform, departure time, destination and more.

=head1 ACCESSORS

=over

=item $departure->destination

Returns the name of the destination station, e.g. "Dortmund Hbf".

=item $departure->info

Returns additional information, usually wether the train is on time or
delayed.

=item $departure->platform

Returns the platform from which the train will depart.

=item $departure->route

Returns a list of station names the train will pass between the selected
station and its destination.

=item $departure->time

Returns the departure time as string in "hh:mm" format.

=item $departure->train

Returns the line / train name, either in a format like "S 1" (S-Bahn line 1)
or "RE 10111" (RegionalExpress train 10111, no line information).

=back

=head1 METHODS

=over

=item $departure = Travel::Status::DE::DeutscheBahn::Departure->new(I<%data>)

Returns a new Travel::Status::DE::DeutscheBahn::Departure object.
You usually do not need to call this.

Required I<data>:

=over

=item B<time> => I<hh:mm>

=item B<train> => I<string>

=item B<route_raw> => I<string>

=item B<route> => I<arrayref>

=item B<destination> => I<string>

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
