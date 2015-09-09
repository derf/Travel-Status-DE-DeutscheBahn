package Travel::Status::DE::HAFAS;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => "experimental::smartmatch";

use Carp qw(confess);
use LWP::UserAgent;
use POSIX qw(strftime);
use Travel::Status::DE::HAFAS::Result;
use XML::LibXML;

our $VERSION = '1.05';

sub new {
	my ( $obj, %conf ) = @_;

	my $date = $conf{date} // strftime( '%d.%m.%Y', localtime(time) );
	my $time = $conf{time} // strftime( '%H:%M',    localtime(time) );
	my $lang    = $conf{language} // 'd';
	my $mode    = $conf{mode}     // 'dep';
	my $service = $conf{service}  // 'DB';

	my %lwp_options = %{ $conf{lwp_options} // { timeout => 10 } };

	my $ua = LWP::UserAgent->new(%lwp_options);

	$ua->env_proxy;

	my $reply;

	if ( not $conf{station} ) {
		confess('You need to specify a station');
	}

	my $ref = {
		active_service => $service,
		developer_mode => $conf{developer_mode},
		post           => {
			input => $conf{station},
			date  => $date,
			time  => $time,
			start => 'yes',         # value doesn't matter, just needs to be set
			boardType => $mode,
			L         => 'vs_java3',
		},
		service => {
			DB => {
				url  => 'http://reiseauskunft.bahn.de/bin/bhftafel.exe',
				name => 'Deutsche Bahn',
				productbits =>
				  [qw[ice ic_ec d nv s bus ferry u tram ondemand x x x x]],
			}
		},
	};

	bless( $ref, $obj );

	$ref->set_productfilter;

	my $url = $ref->{service}{$service}{url} . '/' . $lang . 'n';

	$reply = $ua->post( $url, $ref->{post} );

	if ( $reply->is_error ) {
		$ref->{errstr} = $reply->status_line;
		return $ref;
	}

	# the interface does not return valid XML (but it's close!)
	$ref->{raw_xml}
	  = '<?xml version="1.0" encoding="iso-8859-15"?><wrap>'
	  . $reply->content
	  . '</wrap>';

	if ( $ref->{developer_mode} ) {
		say $ref->{raw_xml};
	}

	$ref->{tree} = XML::LibXML->load_xml(
		string => $ref->{raw_xml},

		#		recover           => 2,
		#		suppress_errors   => 1,
		#		suppress_warnings => 1,
	);

	if ( $ref->{developer_mode} ) {
		say $ref->{tree}->toString(1);
	}

	$ref->check_input_error;
	return $ref;
}

sub set_productfilter {
	my ($self) = @_;

	my $service = $self->{active_service};

	$self->{post}{productsFilter}
	  = '1' x ( scalar @{ $self->{service}{$service}{productbits} } );
}

sub check_input_error {
	my ($self) = @_;

	my $xp_err = XML::LibXML::XPathExpression->new('//Err');
	my $err    = ( $self->{tree}->findnodes($xp_err) )[0];

	if ($err) {
		$self->{errstr}
		  = $err->getAttribute('text')
		  . ' (code '
		  . $err->getAttribute('code') . ')';
	}

	return;
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub results {
	my ($self) = @_;
	my $mode = $self->{post}->{boardType};

	my $xp_element = XML::LibXML::XPathExpression->new('//Journey');
	my $xp_msg     = XML::LibXML::XPathExpression->new('./HIMMessage');

	if ( defined $self->{results} ) {
		return @{ $self->{results} };
	}
	if ( not defined $self->{tree} ) {
		return;
	}

	$self->{results} = [];

	for my $tr ( @{ $self->{tree}->findnodes($xp_element) } ) {

		my @message_nodes = $tr->findnodes($xp_msg);
		my $train         = $tr->getAttribute('prod');
		my $time          = $tr->getAttribute('fpTime');
		my $date          = $tr->getAttribute('fpDate');
		my $dest          = $tr->getAttribute('targetLoc');
		my $platform      = $tr->getAttribute('platform');
		my $new_platform  = $tr->getAttribute('newpl');
		my $delay         = $tr->getAttribute('delay');
		my $e_delay       = $tr->getAttribute('e_delay');
		my $info          = $tr->getAttribute('delayReason');
		my $routeinfo     = $tr->textContent;
		my @messages;

		if ( not( $time and $dest ) ) {
			next;
		}

		for my $n (@message_nodes) {
			push( @messages, $n->getAttribute('header') );
		}

		substr( $date, 6, 0 ) = '20';

		$info      //= q{};
		$routeinfo //= q{};

		$train =~ s{#.*$}{};

		push(
			@{ $self->{results} },
			Travel::Status::DE::HAFAS::Result->new(
				date          => $date,
				raw_delay     => $delay,
				raw_e_delay   => $e_delay,
				messages      => \@messages,
				time          => $time,
				train         => $train,
				route_end     => $dest,
				platform      => $platform,
				new_platform  => $new_platform,
				info          => $info,
				routeinfo_raw => $routeinfo,
			)
		);
	}

	return @{ $self->{results} };
}

# static
sub get_services {
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

Travel::Status::DE::HAFAS is an interface to HAFAS-based
arrival/departure monitors, for instance the one available at
L<http://reiseauskunft.bahn.de/bin/bhftafel.exe/dn>.

It takes a station name and (optional) date and time and reports all arrivals
or departures at that station starting at the specified point in time (now if
unspecified).

=head1 METHODS

=over

=item my $status = Travel::Status::DE::HAFAS->new(I<%opts>)

Requests the departures/arrivals as specified by I<opts> and returns a new
Travel::Status::DE::HAFAS element with the results.  Dies if the wrong
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

=item B<lwp_options> => I<\%hashref>

Passed on to C<< LWP::UserAgent->new >>. Defaults to C<< { timeout => 10 } >>,
you can use an empty hashref to override it.

=item B<time> => I<hh>:I<mm>

Time to report for.  Defaults to now.

=item B<mode> => B<arr>|B<dep>

By default, Travel::Status::DE::HAFAS reports train departures
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
no error occurred, returns undef.

=item $status->results

Returns a list of arrivals/departures.  Each list element is a
Travel::Status::DE::HAFAS::Result(3pm) object.

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

Unknown.

=head1 SEE ALSO

Travel::Status::DE::HAFAS::Result(3pm).

=head1 AUTHOR

Copyright (C) 2015 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
