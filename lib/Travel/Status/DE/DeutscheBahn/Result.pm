package Travel::Status::DE::DeutscheBahn::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.04';

Travel::Status::DE::DeutscheBahn::Result->mk_ro_accessors(
	qw(time train route_end route_raw platform info_raw));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub destination {
	my ($self) = @_;

	return $self->{route_end};
}

sub info {
	my ($self) = @_;

	my $info = $self->info_raw;

	$info =~ s{ ,Grund }{}ox;
	$info =~ s{ ^ \s+ }{}ox;
	$info =~ s{ (?: ^ | , ) (?: p.nktlich | k [.] A [.] ) }{}ox;
	$info =~ s{ ^ , }{}ox;

	return $info;
}

sub delay {
	my ($self) = @_;

	my $info = $self->info_raw;

	if ( $info =~ m{ p.nktlich }ox ) {
		return 0;
	}
	if ( $info =~ m{ ca[.] \s (?<delay> \d+ ) \s Minuten \s sp.ter }ox ) {
		return $+{delay};
	}

	return;
}

sub origin {
	my ($self) = @_;

	return $self->{route_end};
}

sub route {
	my ($self) = @_;

	return @{ $self->{route} };
}

sub route_interesting {
	my ( $self, $max_parts ) = @_;

	my @via = $self->route;
	my ( @via_main, @via_show, $last_stop );
	$max_parts //= 3;

	for my $stop (@via) {
		if ( $stop =~ m{ ?Hbf}o ) {
			push( @via_main, $stop );
		}
	}
	$last_stop = pop(@via);

	if ( @via_main and $via_main[-1] eq $last_stop ) {
		pop(@via_main);
	}

	if ( @via_main and @via and $via[0] eq $via_main[0] ) {
		shift(@via_main);
	}

	if ( @via < $max_parts ) {
		@via_show = @via;
	}
	else {
		if ( @via_main >= $max_parts ) {
			@via_show = ( $via[0] );
		}
		else {
			@via_show = splice( @via, 0, $max_parts - @via_main );
		}

		while ( @via_show < $max_parts and @via_main ) {
			my $stop = shift(@via_main);
			if ( $stop ~~ \@via_show or $stop eq $last_stop ) {
				next;
			}
			push( @via_show, $stop );
		}
	}

	for (@via_show) {
		s{ ?Hbf}{};
	}

	return @via_show;

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

version 0.04

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

=item $result->delay

Returns the train's delay in minutes, or undef if it is unknown.

=item $result->info

Returns additional information, for instance the reason why the train is
delayed. May be an empty string if no (useful) information is available.

=item $result->platform

Returns the platform from which the train will depart / at which it will
arrive.

=item $result->route

Returns a list of station names the train will pass between the selected
station and its origin/destination.

=item $result->route_interesting([I<max>])

Returns a list of up to I<max> (default: 3) interesting stations the train
will pass on its journey. Since deciding whether a station is interesting or
not is somewhat tricky, this feature should be considered experimental.

The first element of the list is always the train's next stop. The following
elements contain as many main stations as possible, but there may also be
smaller stations if not enough main stations are available.

In future versions, other factors may be taken into account as well.  For
example, right now airport stations are usually not included in this list,
although they should be.

Note that all main stations will be stripped of their "Hbf" suffix.

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

=item B<info_raw> => I<string>

=back

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

Arrival times are present in B<route_raw>, but not accessible via B<route>.

=head1 SEE ALSO

Travel::Status::DE::DeutscheBahn(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
