package Travel::Status::DE::DeutscheBahn;

use strict;
use warnings;
use 5.010;

use Carp qw(confess);
use LWP::UserAgent;
use POSIX qw(strftime);
use Travel::Status::DE::DeutscheBahn::Result;
use XML::LibXML;

our $VERSION = '1.01';

sub new {
	my ( $obj, %conf ) = @_;
	my $date = strftime( '%d.%m.%Y', localtime(time) );
	my $time = strftime( '%H:%M',    localtime(time) );

	my $ua = LWP::UserAgent->new();

	my $reply;

	my $lang = $conf{language} // 'd';

	if ( not $conf{station} ) {
		confess('You need to specify a station');
	}

	my $ref = {
		mot_filter => [
			$conf{mot}->{ice}   // 1,
			$conf{mot}->{ic_ec} // 1,
			$conf{mot}->{d}     // 1,
			$conf{mot}->{nv}    // 1,
			$conf{mot}->{s}     // 1,
			$conf{mot}->{bus}   // 0,
			$conf{mot}->{ferry} // 0,
			$conf{mot}->{u}     // 0,
			$conf{mot}->{tram}  // 0,
		],
		post => {
			advancedProductMode => q{},
			input               => $conf{station},
			date                => $conf{date} || $date,
			time                => $conf{time} || $time,
			REQTrain_name       => q{},
			start               => 'yes',
			boardType           => $conf{mode} // 'dep',

			#			L                   => 'vs_java3',
		},
	};

	for my $i ( 0 .. @{ $ref->{mot_filter} } ) {
		if ( $ref->{mot_filter}->[$i] ) {
			$ref->{post}->{"GUIREQProduct_$i"} = 'on';
		}
	}

	bless( $ref, $obj );

	$reply
	  = $ua->post(
		"http://reiseauskunft.bahn.de/bin/bhftafel.exe/${lang}n?rt=1",
		$ref->{post} );

	if ( $reply->is_error ) {
		$ref->{errstr} = $reply->status_line();
		return $ref;
	}

	$ref->{html} = $reply->content;

	$ref->{tree} = XML::LibXML->load_html(
		string            => $ref->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	$ref->check_input_error();

	return $ref;
}

sub new_from_html {
	my ( $obj, %opt ) = @_;

	my $ref = {
		html => $opt{html},
		post => { boardType => $opt{mode} // 'dep' }
	};

	$ref->{post}->{boardType} = $opt{mode} // 'dep';

	$ref->{tree} = XML::LibXML->load_html(
		string            => $ref->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	return bless( $ref, $obj );
}

sub check_input_error {
	my ($self) = @_;

	my $xp_errdiv = XML::LibXML::XPathExpression->new(
		'//div[@class = "errormsg leftMargin"]');
	my $xp_opts
	  = XML::LibXML::XPathExpression->new('//select[@class = "error"]');
	my $xp_values = XML::LibXML::XPathExpression->new('./option');

	my $e_errdiv = ( $self->{tree}->findnodes($xp_errdiv) )[0];
	my $e_opts   = ( $self->{tree}->findnodes($xp_opts) )[0];

	if ($e_errdiv) {
		$self->{errstr} = $e_errdiv->textContent;

		if ($e_opts) {
			my @nodes = ( $e_opts->findnodes($xp_values) );
			$self->{errstr}
			  .= join( q{}, map { "\n" . $_->textContent } @nodes );
		}
	}

	return;
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub get_node {
	my ( $parent, $name, $xpath, $index ) = @_;
	$index //= 0;

	my @nodes = $parent->findnodes($xpath);

	if ( $#nodes < $index ) {

		# called by map, so we must explicitly return undef.
		## no critic (Subroutines::ProhibitExplicitReturnUndef)
		return undef;
	}

	my $node = $nodes[$index];

	return $node->textContent;
}

sub results {
	my ($self) = @_;
	my $mode = $self->{post}->{boardType};

	my $xp_element = XML::LibXML::XPathExpression->new(
		"//table[\@class = \"result stboard ${mode}\"]/tr");
	my $xp_train_more = XML::LibXML::XPathExpression->new('./td[3]/a');

	# bhftafel.exe is not y2k1-safe
	my $re_morelink = qr{ date = (?<date> .. [.] .. [.] .. ) }x;

	my @parts = (
		[ 'time',     './td[@class="time"]' ],
		[ 'train',    './td[3]' ],
		[ 'route',    './td[@class="route"]' ],
		[ 'dest',     './td[@class="route"]//a' ],
		[ 'platform', './td[@class="platform"]' ],
		[ 'info',     './td[@class="ris"]' ],
	);

	@parts = map { [ $_->[0], XML::LibXML::XPathExpression->new( $_->[1] ) ] }
	  @parts;

	my $re_via = qr{
		^ \s* (?<stop> .+? ) \s* \n
		(?<time> \d{1,2}:\d{1,2} )
	}mx;

	if ( defined $self->{results} ) {
		return @{ $self->{results} };
	}
	if ( not defined $self->{tree} ) {
		return;
	}

	$self->{results} = [];

	for my $tr ( @{ $self->{tree}->findnodes($xp_element) } ) {

		my @via;
		my $first = 1;
		my ( $time, $train, $route, $dest, $platform, $info )
		  = map { get_node( $tr, @{$_} ) } @parts;
		my $e_train_more = ( $tr->findnodes($xp_train_more) )[0];

		if ( not( $time and $dest ) ) {
			next;
		}

		$e_train_more->getAttribute('href') =~ $re_morelink;

		my $date = $+{date};

		substr( $date, 6, 0 ) = '20';

		$platform //= q{};
		$info     //= q{};

		for my $str ( $time, $train, $dest, $platform, $info ) {
			$str =~ s/\n/ /mg;
			$str =~ tr/ //s;
			$str =~ s/^ +//;
			$str =~ s/ +$//;
		}

		while ( $route =~ m{$re_via}g ) {
			if ($first) {
				$first = 0;
				next;
			}

			if ( $+{stop} =~ m{ [(] Halt \s entf.llt [)] }ox ) {
				next;
			}

			push( @via, [ $+{time}, $+{stop} ] );
		}

		push(
			@{ $self->{results} },
			Travel::Status::DE::DeutscheBahn::Result->new(
				date      => $date,
				time      => $time,
				train     => $train,
				route_raw => $route,
				route     => \@via,
				route_end => $dest,
				platform  => $platform,
				info_raw  => $info,
			)
		);
	}

	return @{ $self->{results} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::DeutscheBahn - Interface to the DeutscheBahn online
arrival/departure monitor

=head1 SYNOPSIS

	use Travel::Status::DE::DeutscheBahn;

	my $status = Travel::Status::DE::DeutscheBahn->new(
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

version 1.01

=head1 DESCRIPTION

Travel::Status::DE::DeutscheBahn is an interface to the DeutscheBahn
arrival/departure monitor available at
L<http://reiseauskunft.bahn.de/bin/bhftafel.exe/dn>.

It takes a station name and (optional) date and time and reports all arrivals
or departures at that station starting at the specified point in time (now if
unspecified).

=head1 METHODS

=over

=item my $status = Travel::Status::DE::DeutscheBahn->new(I<%opts>)

Requests the departures/arrivals as specified by I<opts> and returns a new
Travel::Status::DE::DeutscheBahn element with the results.  Dies if the wrong
I<opts> were passed.

Supported I<opts> are:

=over

=item B<station> => I<station>

The train station to report for, e.g.  "Essen HBf" or
"Alfredusbad, Essen (Ruhr)".  Mandatory.

=item B<date> => I<dd>.I<mm>.I<yyyy>

Date to report for.  Defaults to the current day.

=item B<language> => I<language>

Set language for additional information. Accepted arguments: B<d>eutsch,
B<e>nglish, B<i>talian, B<n> (dutch).

=item B<time> => I<hh>:I<mm>

Time to report for.  Defaults to now.

=item B<mode> => B<arr>|B<dep>

By default, Travel::Status::DE::DeutscheBahn reports train departures
(B<dep>).  Set this to B<arr> to get arrivals instead.

=item B<mot> => I<\%hashref>

Modes of transport to show.  Accepted keys are: B<ice> (ICE trains), B<ic_ec>
(IC and EC trains), B<d> (InterRegio and similarly fast trains), B<nv>
("Nahverkehr", mostly RegionalExpress trains), B<s> ("S-Bahn"), B<bus>,
B<ferry>, B<u> ("U-Bahn") and B<tram>.

Setting a mode (as hash key) to 1 includes it, 0 excludes it.  undef leaves it
at the default.

By default, the following are shown: ice, ic_ec, d, nv, s.

=back

=item $status->errstr

In case of an error in the HTTP request, returns a string describing it.  If
no error occured, returns undef.

=item $status->results

Returns a list of arrivals/departures.  Each list element is a
Travel::Status::DE::DeutscheBahn::Result(3pm) object.

If no matching results were found or the parser / http request failed, returns
undef.

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

There are a few character encoding issues.

=head1 SEE ALSO

Travel::Status::DE::DeutscheBahn::Result(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
