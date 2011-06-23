package Travel::Status::DE::DeutscheBahn;

use strict;
use warnings;
use 5.010;

use Carp qw(confess);
use LWP::UserAgent;
use POSIX qw(strftime);
use Travel::Status::DE::DeutscheBahn::Departure;
use XML::LibXML;

our $VERSION = '0.0';

sub new {
	my ( $obj, %conf ) = @_;
	my $date = strftime( '%d.%m.%Y', localtime(time) );
	my $time = strftime( '%H:%M',    localtime(time) );

	my $ua = LWP::UserAgent->new();

	if ( not $conf{station} ) {
		confess('You need to specify a station');
	}

	my $ref = {
		post => {
			input          => $conf{station},
			inputRef       => q{#},
			date           => $conf{date} || $date,
			time           => $conf{time} || $time,
			productsFilter => '1111101000000000',
			REQTrain_name  => q{},
			maxJourneys    => 20,
			delayedJourney => undef,
			start          => 'Suchen',
			boardType      => 'Abfahrt',
			ao             => 'yes',
		},
	};

	$ref->{html}
	  = $ua->post( 'http://reiseauskunft.bahn.de/bin/bhftafel.exe/dn?rt=1',
		$ref->{post} )->content();

	$ref->{tree} = XML::LibXML->load_html(
		string            => $ref->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	return bless( $ref, $obj );
}

sub new_from_html {
	my ( $obj, $html ) = @_;

	my $ref = { html => $html, };

	$ref->{tree} = XML::LibXML->load_html(
		string            => $ref->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	return bless( $ref, $obj );
}

sub departures {
	my ($self) = @_;

	my $xp_element = XML::LibXML::XPathExpression->new(
		'//table[@class="result stboard dep"]/tr');
	my $xp_time  = XML::LibXML::XPathExpression->new('./td[@class="time"]');
	my $xp_train = XML::LibXML::XPathExpression->new('./td[@class="train"]');
	my $xp_route = XML::LibXML::XPathExpression->new('./td[@class="route"]');
	my $xp_dest  = XML::LibXML::XPathExpression->new('./td[@class="route"]//a');
	my $xp_platform
	  = XML::LibXML::XPathExpression->new('./td[@class="platform"]');
	my $xp_info = XML::LibXML::XPathExpression->new('./td[@class="ris"]');

	my $re_via = qr{
		^ \s* (.+?) \s* \n
		\d{1,2}:\d{1,2}
	}mx;

	for my $tr ( @{ $self->{tree}->findnodes($xp_element) } ) {

		my ($n_time) = $tr->findnodes($xp_time);
		my ( undef, $n_train ) = $tr->findnodes($xp_train);
		my ($n_route)    = $tr->findnodes($xp_route);
		my ($n_dest)     = $tr->findnodes($xp_dest);
		my ($n_platform) = $tr->findnodes($xp_platform);
		my ($n_info)     = $tr->findnodes($xp_info);
		my $first        = 1;

		if ( not( $n_time and $n_dest ) ) {
			next;
		}

		my $time     = $n_time->textContent();
		my $train    = $n_train->textContent();
		my $route    = $n_route->textContent();
		my $dest     = $n_dest->textContent();
		my $platform = $n_platform->textContent();
		my $info     = $n_info->textContent();
		my @via;

		for my $str ( $time, $train, $dest, $platform, $info ) {
			$str =~ s/\n//mg;
			$str =~ tr/ //s;
		}

		$info =~ s/,Grund//;

		while ( $route =~ m{$re_via}g ) {
			if ($first) {
				$first = 0;
				next;
			}
			my $stop = $1;
			push( @via, $stop );
		}

		push(
			@{ $self->{departures} },
			Travel::Status::DE::DeutscheBahn::Departure->new(
				time        => $time,
				train       => $train,
				route_raw   => $route,
				route       => \@via,
				destination => $dest,
				platform    => $platform,
				info        => $info,
			)
		);
	}

	return @{ $self->{departures} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::DeutscheBahn - Interface to the DeutscheBahn online
departure monitor

=head1 SYNOPSIS

	use Travel::Status::DE::DeutscheBahn;

	my $status = Travel::Status::DE::DeutscheBahn->new(
		station => 'Essen Hbf',
	);

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

Travel::Status::DE::DeutscheBahn is an interface to the DeutscheBahn
arrival/departure monitor available at
L<http://reiseauskunft.bahn.de/bin/bhftafel.exe/dn>.

It takes a station name and (optional) date and time and reports all
departures at that station starting at the specified point in time (now if
unspecified). By default, it will list the next 20 departures.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::DeutscheBahn->new(I<%opts>)

Returns a new Travel::Status::DE::DeutscheBahn element. Supported I<opts> are:

=over

=item B<station> => I<station>

The train station to report for, e.g. "Essen HBf". Mandatory.

=item B<date> => I<dd>.I<mm>.I<yyyy>

Date to report for. Defaults to the current day.

=item B<time> => I<hh>:I<mm>

Time to report for. Defaults to now.

=back

=item $status->departures()

Returns a list of departures (20 by default). Each list element is a
Travel::Status::DE::DeutscheBahn::Departure(3pm) object.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * LWP::UserAgent(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

The web interface also offers arrival monitoring. This is not yet supported
in this module.

=head1 SEE ALSO

mris(1), Travel::Status::DE::DeutscheBahn::Departure(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
