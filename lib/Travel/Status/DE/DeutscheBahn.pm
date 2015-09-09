package Travel::Status::DE::DeutscheBahn;

use strict;
use warnings;
use 5.010;

use parent 'Travel::Status::DE::HAFAS';

our $VERSION = '1.05';

sub new {
	my ( $class, %opt ) = @_;

	$opt{service} = 'deutschebahn';

	return $class->SUPER::new(%opt);
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS - Interface to HAFAS-based online arrival/departure
monitors

=head1 SYNOPSIS

	use Travel::Status::DE::HAFAS;

	my $status = Travel::Status::DE::HAFAS->new(
		station => 'Essen Hbf',
	);

	if (my $err = $status->errstr) {
		die("Request error: ${err}\n");
	}

	for my $departure ($status->results) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->time,
			$departure->line,
			$departure->destination,
			$departure->platform,
		);
	}

=head1 VERSION

version 1.05

=head1 DESCRIPTION

Travel::Status::DE::DeutscheBahn is an interface to the Deutsche Bahn
departure monitor available at
L<http://reiseauskunft.bahn.de/bin/bhftafel.exe/dn>.

It takes a station name and (optional) date and time and reports all arrivals
or departures at that station starting at the specified point in time (now if
unspecified).

=head1 METHODS

=over

=item my $status = Travel::Status::DE::DeutscheBahn->new(I<%opts>)

Requests the departures/arrivals as specified by I<opts> and returns a new
Travel::Status::DE::HAFAS element with the results.  Dies if the wrong
I<opts> were passed.

Calls Travel::Status::DE::HAFAS->new with service = DB. All I<opts> are passed
on. Please see Travel::Status::DE::HAFAS(3pm) for I<opts> documentation
and other methdos.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * LWP::UserAgent(3pm)

=item * Travel::Status::DE::HAFAS(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

Unknown.

=head1 SEE ALSO

Travel::Status::DE::HAFAS(3pm).

=head1 AUTHOR

Copyright (C) 2015 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
