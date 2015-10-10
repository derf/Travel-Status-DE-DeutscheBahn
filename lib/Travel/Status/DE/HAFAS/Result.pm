package Travel::Status::DE::HAFAS::Result;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use parent 'Class::Accessor';

our $VERSION = '2.00';

Travel::Status::DE::HAFAS::Result->mk_ro_accessors(
	qw(date info raw_e_delay raw_delay time train route_end));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub delay {
	my ($self) = @_;

	if ( defined $self->{raw_e_delay} ) {
		return $self->{raw_e_delay};
	}
	if (    defined $self->{raw_delay}
		and $self->{raw_delay} ne q{-}
		and $self->{raw_delay} ne 'cancel' )
	{
		return $self->{raw_delay};
	}
	return;
}

sub destination {
	my ($self) = @_;

	return $self->{route_end};
}

sub line {
	my ($self) = @_;

	return $self->{train};
}

sub is_cancelled {
	my ($self) = @_;

	if ( $self->{raw_delay} and $self->{raw_delay} eq 'cancel' ) {
		return 1;
	}
	return 0;
}

sub is_changed_platform {
	my ($self) = @_;

	if ( defined $self->{new_platform} and defined $self->{platform} ) {
		if ( $self->{new_platform} ne $self->{platform} ) {
			return 1;
		}
		return 0;
	}
	if ( defined $self->{net_platform} ) {
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

sub origin {
	my ($self) = @_;

	return $self->{route_end};
}

sub platform {
	my ($self) = @_;

	return $self->{new_platform} // $self->{platform};
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

sub type {
	my ($self) = @_;
	my $type;

	# $self->{train} is either "TYPE 12345" or "TYPE12345"
	if ( $self->{train} =~ m{ \s }x ) {
		($type) = ( $self->{train} =~ m{ ^ ([^[:space:]]+) }x );
	}
	else {
		($type) = ( $self->{train} =~ m{ ^ ([[:alpha:]]+) }x );
	}

	return $type;
}

sub line_no {
	my ($self) = @_;
	my $line_no;

	# $self->{train} is either "TYPE 12345" or "TYPE12345"
	if ( $self->{train} =~ m{ \s }x ) {
		($line_no) = ( $self->{train} =~ m{ ([^[:space:]]+) $ }x );
	}
	else {
		($line_no) = ( $self->{train} =~ m{ ([[:digit:]]+) $ }x );
	}

	return $line_no;
}

sub train_no {
	my ($self) = @_;

	return $self->line_no;
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Result - Information about a single
arrival/departure received by Travel::Status::DE::HAFAS

=head1 SYNOPSIS

	for my $departure ($status->results) {
		printf(
			"At %s: %s to %s from platform %s\n",
			$departure->time,
			$departure->line,
			$departure->destination,
			$departure->platform,
		);
	}

	# or (depending on module setup)
	for my $arrival ($status->results) {
		printf(
			"At %s: %s from %s on platform %s\n",
			$arrival->time,
			$arrival->line,
			$arrival->origin,
			$arrival->platform,
		);
	}

=head1 VERSION

version 2.00

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Result describes a single arrival/departure
as obtained by Travel::Status::DE::HAFAS.  It contains information about
the platform, time, route and more.

=head1 METHODS

=head2 ACCESSORS

=over

=item $result->date

Arrival/Departure date in "dd.mm.yyyy" format.

=item $result->delay

Returns the delay in minutes, or undef if it is unknown.
Also returns undef if the arrival/departure has been cancelled.

=item $result->info

Returns additional information, for instance the most recent delay reason.
undef if no (useful) information is available.

=item $result->is_cancelled

True if the arrival/departure was cancelled, false otherwise.

=item $result->is_changed_platform

True if the platform (as returned by the B<platform> accessor) is not the
scheduled one. Note that the scheduled platform is unknown in this case.

=item $result->messages

Returns a list of message strings related to this result. Messages usually are
service notices (e.g. "missing carriage") or detailed delay reasons
(e.g. "switch damage between X and Y, expect delays").

=item $result->line

=item $result->train

Returns the line name, either in a format like "Bus SB16" (Bus line SB16)
or "RE 10111" (RegionalExpress train 10111, no line information).
May contain extraneous whitespace characters.

=item $result->line_no

=item $result->train_no

Returns the line/train number, for instance "SB16" (bus line SB16),
"11" (Underground train line U 11) or 1011 ("RegionalExpress train 1011").
Note that this may not be a number at all: Some transport services also
use single-letter characters or words (e.g. "AIR") as line numbers.

=item $result->platform

Returns the arrival/departure platform.
Realtime data if available, schedule data otherwise.

=item $result->route_end

=item $result->destination

=item $result->origin

Returns the last element of the route.  Depending on how you set up
Travel::Status::DE::HAFAS (arrival or departure listing), this is
either the result's destination or its origin station.

=item $result->time

Returns the arrival/departure time as string in "hh:mm" format.

=item $result->type

Returns the type of this result, e.g. "S" for S-Bahn, "RE" for Regional Express
or "STR" for tram / StraE<szlig>enbahn.

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

Copyright (C) 2015 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
