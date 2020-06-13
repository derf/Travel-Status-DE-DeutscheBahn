package Travel::Status::DE::HAFAS;

use strict;
use warnings;
use 5.014;
use utf8;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Carp qw(confess);
use DateTime;
use DateTime::Format::Strptime;
use List::Util qw(any);
use LWP::UserAgent;
use POSIX qw(strftime);
use Travel::Status::DE::HAFAS::Result;
use Travel::Status::DE::HAFAS::StopFinder;
use XML::LibXML;

our $VERSION = '3.01';

my %hafas_instance = (

	#BVG => {
	#	url         => 'https://bvg.hafas.de/bin/stboard.exe',
	#	stopfinder  => 'https://bvg.hafas.de/bin/ajax-getstop.exe',
	#	name        => 'Berliner Verkehrsgesellschaft',
	#	productbits => [qw[s u tram bus ferry ice regio ondemand]],
	#},
	DB => {
		url         => 'https://reiseauskunft.bahn.de/bin/bhftafel.exe',
		stopfinder  => 'https://reiseauskunft.bahn.de/bin/ajax-getstop.exe',
		trainsearch => 'https://reiseauskunft.bahn.de/bin/trainsearch.exe',
		traininfo   => 'https://reiseauskunft.bahn.de/bin/traininfo.exe',
		name        => 'Deutsche Bahn',
		productbits =>
		  [qw[ice ic_ec d regio s bus ferry u tram ondemand x x x x]],
	},
	NAHSH => {
		url         => 'https://nah.sh.hafas.de/bin/stboard.exe',
		stopfinder  => 'https://nah.sh.hafas.de/bin/ajax-getstop.exe',
		name        => 'Nahverkehrsverbund Schleswig-Holstein',
		productbits => [qw[ice ice ice regio s bus ferry u tram ondemand]],
	},
	NASA => {
		url         => 'https://reiseauskunft.insa.de/bin/stboard.exe',
		stopfinder  => 'https://reiseauskunft.insa.de/bin/ajax-getstop.exe',
		name        => 'Nahverkehrsservice Sachsen-Anhalt',
		productbits => [qw[ice ice regio regio regio tram bus ondemand]],
	},
	NVV => {
		url => 'https://auskunft.nvv.de/auskunft/bin/jp/stboard.exe',
		stopfinder =>
		  'https://auskunft.nvv.de/auskunft/bin/jp/ajax-getstop.exe',
		name => 'Nordhessischer VerkehrsVerbund',
		productbits =>
		  [qw[ice ic_ec regio s u tram bus bus ferry ondemand regio regio]],
	},
	'ÖBB' => {
		url        => 'https://fahrplan.oebb.at/bin/stboard.exe',
		stopfinder => 'https://fahrplan.oebb.at/bin/ajax-getstop.exe',
		name       => 'Österreichische Bundesbahnen',
		productbits =>
		  [qw[ice ice ice regio regio s bus ferry u tram ice ondemand ice]],
	},
	RSAG => {
		url         => 'https://fahrplan.rsag-online.de/hafas/stboard.exe',
		stopfinder  => 'https://fahrplan.rsag-online.de/hafas/ajax-getstop.exe',
		name        => 'Rostocker Straßenbahn AG',
		productbits => [qw[ice ice ice regio s bus ferry u tram ondemand]],
	},

	#SBB => {
	#	url        => 'https://fahrplan.sbb.ch/bin/stboard.exe',
	#	stopfinder => 'https://fahrplan.sbb.ch/bin/ajax-getstop.exe',
	#	name       => 'Schweizerische Bundesbahnen',
	#	productbits =>
	#	  [qw[ice ice regio regio ferry s bus cablecar regio tram]],
	#},
	VBB => {
		url         => 'https://fahrinfo.vbb.de/bin/stboard.exe',
		stopfinder  => 'https://fahrinfo.vbb.de/bin/ajax-getstop.exe',
		name        => 'Verkehrsverbund Berlin-Brandenburg',
		productbits => [qw[s u tram bus ferry ice regio]],
	},
	VBN => {
		url         => 'https://fahrplaner.vbn.de/hafas/stboard.exe',
		stopfinder  => 'https://fahrplaner.vbn.de/hafas/ajax-getstop.exe',
		name        => 'Verkehrsverbund Bremen/Niedersachsen',
		productbits => [qw[ice ice regio regio s bus ferry u tram ondemand]],
	},
);

sub new {
	my ( $obj, %conf ) = @_;

	my $date = $conf{date} // strftime( '%d.%m.%Y', localtime(time) );
	my $time = $conf{time} // strftime( '%H:%M',    localtime(time) );
	my $lang = $conf{language} // 'd';
	my $mode = $conf{mode}     // 'dep';
	my $service = $conf{service};

	my %lwp_options = %{ $conf{lwp_options} // { timeout => 10 } };

	my $ua = LWP::UserAgent->new(%lwp_options);

	$ua->env_proxy;

	my $reply;

	if ( not $conf{station} ) {
		confess('You need to specify a station');
	}

	if ( not defined $service and not defined $conf{url} ) {
		$service = 'DB';
	}

	if ( defined $service and not exists $hafas_instance{$service} ) {
		confess("The service '$service' is not supported");
	}

	my $ref = {
		active_service => $service,
		developer_mode => $conf{developer_mode},
		exclusive_mots => $conf{exclusive_mots},
		excluded_mots  => $conf{excluded_mots},
		messages       => [],
		results        => [],
		station        => $conf{station},
		ua             => $ua,
		post           => {
			input => $conf{station},
			date  => $date,
			time  => $time,
			start => 'yes',         # value doesn't matter, just needs to be set
			boardType => $mode,
			L         => 'vs_java3',
		},
	};

	bless( $ref, $obj );

	$ref->set_productfilter;

	my $url = ( $conf{url} // $hafas_instance{$service}{url} ) . "/${lang}n";

	if ( $conf{xml} ) {
		$ref->{raw_xml} = $conf{xml};
	}
	else {
		$reply = $ua->post( $url, $ref->{post} );

		if ( $reply->is_error ) {
			$ref->{errstr} = $reply->status_line;
			return $ref;
		}

		$ref->{raw_xml} = $reply->content;
	}

	# the interface often does not return valid XML (but it's close!)
	if ( substr( $ref->{raw_xml}, 0, 5 ) ne '<?xml' ) {
		$ref->{raw_xml}
		  = '<?xml version="1.0" encoding="iso-8859-15"?><wrap>'
		  . $ref->{raw_xml}
		  . '</wrap>';
	}

	if ( defined $service and $service =~ m{ ^ VBB | NVV $ }x ) {

		# Returns invalid XML with tags inside HIMMessage's lead attribute.
		# Fix this.
		$ref->{raw_xml}
		  =~ s{ lead = " \K ( [^"]+ ) }{ $1 =~ s{ < [^>]+ > }{}grx }egx;
	}

	# TODO the DB backend also retuns invalid XML (similar to above, but with
	# errors in delay="...") when setting the language to dutch/italian.
	# No, I don't know why.

	$ref->{tree} = XML::LibXML->load_xml(
		string => $ref->{raw_xml},
	);

	if ( $ref->{developer_mode} ) {
		say $ref->{tree}->toString(1);
	}

	$ref->check_input_error;
	$ref->prepare_results;
	return $ref;
}

sub set_productfilter {
	my ($self) = @_;

	my $service     = $self->{active_service};
	my $mot_default = '1';

	if ( not $service or not exists $hafas_instance{$service}{productbits} ) {
		return;
	}

	my %mot_pos;
	for my $i ( 0 .. $#{ $hafas_instance{$service}{productbits} } ) {
		$mot_pos{ $hafas_instance{$service}{productbits}[$i] } = $i;
	}

	if ( $self->{exclusive_mots} and @{ $self->{exclusive_mots} } ) {
		$mot_default = '0';
	}

	$self->{post}{productsFilter}
	  = $mot_default x ( scalar @{ $hafas_instance{$service}{productbits} } );

	if ( $self->{exclusive_mots} and @{ $self->{exclusive_mots} } ) {
		for my $mot ( @{ $self->{exclusive_mots} } ) {
			if ( exists $mot_pos{$mot} ) {
				substr( $self->{post}{productsFilter}, $mot_pos{$mot}, 1, '1' );
			}
		}
	}

	if ( $self->{excluded_mots} and @{ $self->{excluded_mots} } ) {
		for my $mot ( @{ $self->{excluded_mots} } ) {
			if ( exists $mot_pos{$mot} ) {
				substr( $self->{post}{productsFilter}, $mot_pos{$mot}, 1, '0' );
			}
		}
	}

	return;
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
		$self->{errcode} = $err->getAttribute('code');
	}

	return;
}

sub errcode {
	my ($self) = @_;

	return $self->{errcode};
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub similar_stops {
	my ($self) = @_;

	my $service = $self->{active_service};

	if ( $service and exists $hafas_instance{$service}{stopfinder} ) {

		# we do not pass our constructor's language argument here,
		# because most stopfinder services do not return any results
		# for languages other than german ('d' aka the default)
		my $sf = Travel::Status::DE::HAFAS::StopFinder->new(
			url            => $hafas_instance{$service}{stopfinder},
			input          => $self->{station},
			ua             => $self->{ua},
			developer_mode => $self->{developer_mode},
		);
		if ( my $err = $sf->errstr ) {
			$self->{errstr} = $err;
			return;
		}
		return $sf->results;
	}
	return;
}

sub add_message_node {
	my ( $self, $node ) = @_;

	my $header = $node->getAttribute('header');
	my $lead   = $node->getAttribute('lead');

	for my $message ( @{ $self->{messages} } ) {
		if ( $header eq $message->{header} and $lead eq $message->{lead} ) {
			$message->{ref_count}++;
			return $message;
		}
	}
	my $message = {
		header    => $header,
		lead      => $lead,
		ref_count => 1,
	};
	push( @{ $self->{messages} }, $message );
	return $message;
}

sub messages {
	my ($self) = @_;
	return @{ $self->{messages} };
}

sub prepare_results {
	my ($self) = @_;
	my $mode = $self->{post}->{boardType};

	my $xp_element = XML::LibXML::XPathExpression->new('//Journey');
	my $xp_msg     = XML::LibXML::XPathExpression->new('./HIMMessage');

	if ( not defined $self->{tree} ) {
		return;
	}

	$self->{results} = [];

	$self->{datetime_now} //= DateTime->now(
		time_zone => 'Europe/Berlin',
	);
	$self->{strptime_obj} //= DateTime::Format::Strptime->new(
		pattern   => '%d.%m.%YT%H:%M',
		time_zone => 'Europe/Berlin',
	);

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
		my $operator      = $tr->getAttribute('operator');
		my @messages;

		if ( not( $time and $dest ) ) {
			next;
		}

		for my $n (@message_nodes) {
			push( @messages, $self->add_message_node($n) );
		}

		# Some backends report dd.mm.yy, some report dd.mm.yyyy
		# -> map all dates to dd.mm.yyyy
		if ( length($date) == 8 ) {
			substr( $date, 6, 0, '20' );
		}

		# TODO the first charactor of delayReason is special:
		# " " -> no additional data, rest (if any) is delay reason
		# else -> first word is not a delay reason but additional data,
		# for instance "Zusatzfahrt/Ersatzfahrt" for a replacement train
		if ( defined $info and $info eq q{ } ) {
			$info = undef;
		}
		elsif ( defined $info and substr( $info, 0, 1 ) eq q{ } ) {
			substr( $info, 0, 1, q{} );
		}

		$train =~ s{#.*$}{};

		my $datetime = $self->{strptime_obj}->parse_datetime("${date}T${time}");

		push(
			@{ $self->{results} },
			Travel::Status::DE::HAFAS::Result->new(
				sched_date     => $date,
				sched_datetime => $datetime,
				datetime_now   => $self->{datetime_now},
				raw_delay      => $delay,
				raw_e_delay    => $e_delay,
				messages       => \@messages,
				sched_time     => $time,
				train          => $train,
				operator       => $operator,
				route_end      => $dest,
				platform       => $platform,
				new_platform   => $new_platform,
				info           => $info,
			)
		);
	}
}

sub results {
	my ($self) = @_;
	return @{ $self->{results} };
}

# static
sub get_services {
	my @services;
	for my $service ( sort keys %hafas_instance ) {
		my %desc = %{ $hafas_instance{$service} };
		$desc{shortname} = $service;
		push( @services, \%desc );
	}
	return @services;
}

# static
sub get_service {
	my ($service) = @_;

	if ( defined $service and exists $hafas_instance{$service} ) {
		return $hafas_instance{$service};
	}
	return;
}

sub get_active_service {
	my ($self) = @_;

	if ( defined $self->{active_service} ) {
		return $hafas_instance{ $self->{active_service} };
	}
	return;
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

version 3.01

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

The station or stop to report for, e.g.  "Essen HBf" or
"Alfredusbad, Essen (Ruhr)".  Mandatory.

=item B<date> => I<dd>.I<mm>.I<yyyy>

Date to report for.  Defaults to the current day.

=item B<excluded_mots> => [I<mot1>, I<mot2>, ...]

By default, all modes of transport (trains, trams, buses etc.) are returned.
If this option is set, all modes appearing in I<mot1>, I<mot2>, ... will
be excluded. The supported modes depend on B<service>, use
B<get_services> or B<get_service> to get the supported values.

Note that this parameter does not work if the B<url> parameter is set.

=item B<exclusive_mots> => [I<mot1>, I<mot2>, ...]

If this option is set, only the modes of transport appearing in I<mot1>,
I<mot2>, ...  will be returned.  The supported modes depend on B<service>, use
B<get_services> or B<get_service> to get the supported values.

Note that this parameter does not work if the B<url> parameter is set.

=item B<language> => I<language>

Set language for additional information. Accepted arguments are B<d>eutsch,
B<e>nglish, B<i>talian and B<n> (dutch), depending on the used service.

=item B<lwp_options> => I<\%hashref>

Passed on to C<< LWP::UserAgent->new >>. Defaults to C<< { timeout => 10 } >>,
you can use an empty hashref to override it.

=item B<mode> => B<arr>|B<dep>

By default, Travel::Status::DE::HAFAS reports train departures
(B<dep>).  Set this to B<arr> to get arrivals instead.

=item B<service> => I<service>

Request results from I<service>, defaults to "DB".
See B<get_services> (and C<< hafas-m --list >>) for a list of supported
services.

=item B<time> => I<hh>:I<mm>

Time to report for.  Defaults to now.

=item B<url> => I<url>

Request results from I<url>, defaults to the one belonging to B<service>.

=back

=item $status->errcode

In case of an error in the HAFAS backend, returns the corresponding error code
as string. If no backend error occurred, returns undef.

=item $status->errstr

In case of an error in the HTTP request or HAFAS backend, returns a string
describing it.  If no error occurred, returns undef.

=item $status->results

Returns a list of arrivals/departures.  Each list element is a
Travel::Status::DE::HAFAS::Result(3pm) object.

If no matching results were found or the parser / http request failed, returns
undef.

=item $status->similar_stops

Returns a list of hashrefs describing stops whose name is similar to the one
requested in the constructor's B<station> parameter. Returns nothing if
the active service does not support this feature.
This is most useful if B<errcode> returns 'H730', which means that the
HAFAS backend could not identify the stop.

See Travel::Status::DE::HAFAS::StopFinder(3pm)'s B<results> method for details
on the return value.

=item $status->get_active_service

Returns a hashref describing the active service when a service is active and
nothing otherwise. The hashref contains the keys B<url> (URL to the station
board service), B<stopfinder> (URL to the stopfinder service, if supported),
B<name>, and B<productbits> (arrayref describing the supported modes of
transport, may contain duplicates).

=item Travel::Status::DE::HAFAS::get_services()

Returns an array containing all supported HAFAS services. Each element is a
hashref and contains all keys mentioned in B<get_active_service>.
It also contains a B<shortname> key, which is the service name used by
the constructor's B<service> parameter.

=item Travel::Status::DE::HAFAS::get_service(I<$service>)

Returns a hashref describing the service I<$service>. Returns nothing if
I<$service> is not supported. See B<get_active_service> for the hashref layout.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * DateTime(3pm)

=item * DateTime::Format::Strptime(3pm)

=item * LWP::UserAgent(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

The non-default services (anything other than DB) are not well tested.

=head1 SEE ALSO

Travel::Status::DE::HAFAS::Result(3pm), Travel::Status::DE::HAFAS::StopFinder(3pm).

=head1 AUTHOR

Copyright (C) 2015-2020 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
