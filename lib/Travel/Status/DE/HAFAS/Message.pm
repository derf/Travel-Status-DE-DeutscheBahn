package Travel::Status::DE::HAFAS::Message;

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '6.21';

Travel::Status::DE::HAFAS::Message->mk_ro_accessors(
	qw(short type text code prio is_him ref_count));

sub new {
	my ( $obj, %conf ) = @_;

	my $json   = $conf{json};
	my $is_him = $conf{is_him};

	my $short = $json->{txtS};
	my $text  = $json->{txtN};
	my $type  = $json->{type};
	my $code  = $json->{code};
	my $prio  = $json->{prio};

	if ($is_him) {
		$short = $json->{head};
		$text  = $json->{text};
		$code  = $json->{hid};
	}

	my $ref = {
		short     => $short,
		text      => $text,
		type      => $type,
		code      => $code,
		prio      => $prio,
		is_him    => $is_him,
		ref_count => $conf{ref_count},
	};

	bless( $ref, $obj );

	return $ref;
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Message - An arrival/departure-related message.

=head1 SYNOPSIS

	if ($message->text) {
		printf("%s: %s\n", $message->short, $message->text);
	}
	else {
		say $message->short;
	}

=head1 VERSION

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Message describes a message belonging to an
arrival or departure. Messages may refer to planned schedule changes due to
construction work, the expected passenger volume, or similar.

=head1 METHODS

=head2 ACCESSORS

=over

=item $message->short

Message header. May be a concise single-sentence summary or a mostly useless
string such as "Information". Does not contain newlines.

=item $message->text

Detailed message content. Does not contain newlines.

=item $message->code

Two-digit message code, seems to be only used with messages of type "A".
Details unknown.

=item $message->type

A single character indicating the message type.
The following types are known:

=over

=item A

Generic information about a specific trip such as "WiFi available", "air
conditioning", "DB tickets are not valid here", or "from here on as [line]
towards [destination]".

=item C

"Current information available", "Journey cancelled", "connection may not be caught", possibly more.

=item D

Large-scale disruption, e.g. medical emergency on line.

=item G

Platform change, possibly more.

=item H

Misc stuff such as "Journey contains trains with mandatory reservation" or
"ICE Sprinter".

=item L

Replacement journey

=item M

Free-text infos about construction sites, broken elevators, large events and
similar occasions.

=item P

Journey has been cancelled, possibly more.

=back

=item $message->ref_count

Counter indicating how often this message is used by the requested
arrivals/departures. ref_count is an integer between 1 and the number of
results.  If ref_count is 1, it is referenced by a single result only.

=item $message->is_him

True if it is a HIM message (typically used for service information), false
if not (message may be a REM instead, indicating e.g. presence of a bicycle
carriage or WiFi).

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

Copyright (C) 2020-2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
