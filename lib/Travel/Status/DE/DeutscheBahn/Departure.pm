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

=head1 VERSION

version

=head1 DESCRIPTION

=head1 METHODS

=over

=back

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=back

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
