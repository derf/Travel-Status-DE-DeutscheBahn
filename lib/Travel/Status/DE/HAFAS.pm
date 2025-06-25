package Travel::Status::DE::HAFAS;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;
use utf8;

use Carp qw(confess);
use DateTime;
use DateTime::Format::Strptime;
use Digest::MD5 qw(md5_hex);
use Encode      qw(decode encode);
use IO::Socket::SSL;
use JSON;
use LWP::UserAgent;
use Travel::Status::DE::HAFAS::Journey;
use Travel::Status::DE::HAFAS::Location;
use Travel::Status::DE::HAFAS::Message;
use Travel::Status::DE::HAFAS::Polyline qw(decode_polyline);
use Travel::Status::DE::HAFAS::Product;
use Travel::Status::DE::HAFAS::Services;
use Travel::Status::DE::HAFAS::StopFinder;

our $VERSION = '6.21';

# {{{ Endpoint Definition

# Data sources: <https://github.com/public-transport/transport-apis> and
# <https://github.com/public-transport/hafas-client/tree/main/p>. Thanks to
# Jannis R / @derhuerst and all contributors for maintaining these.
my $hafas_instance = Travel::Status::DE::HAFAS::Services::get_service_ref();

# }}}
# {{{ Constructors

sub new {
	my ( $obj, %conf ) = @_;
	my $service = $conf{service};

	my $ua = $conf{user_agent};

	if ( not $ua ) {
		my %lwp_options = %{ $conf{lwp_options} // { timeout => 10 } };
		if ( $service and $hafas_instance->{$service}{ua_string} ) {
			$lwp_options{agent} = $hafas_instance->{$service}{ua_string};
		}
		if ( $service
			and my $geoip_service = $hafas_instance->{$service}{geoip_lock} )
		{
			if ( my $proxy = $ENV{"HAFAS_PROXY_${geoip_service}"} ) {
				$lwp_options{proxy} = [ [ 'http', 'https' ] => $proxy ];
			}
		}
		if ( $service and not $hafas_instance->{$service}{tls_verify} ) {
			$lwp_options{ssl_opts}{SSL_verify_mode}
			  = IO::Socket::SSL::SSL_VERIFY_NONE;
			$lwp_options{ssl_opts}{verify_hostname} = 0;
		}
		$ua = LWP::UserAgent->new(%lwp_options);
		$ua->env_proxy;
	}

	if (
		not(   $conf{station}
			or $conf{journey}
			or $conf{journeyMatch}
			or $conf{geoSearch}
			or $conf{locationSearch} )
	  )
	{
		confess(
'station / journey / journeyMatch / geoSearch / locationSearch must be specified'
		);
	}

	if ( not defined $service ) {
		confess("You must specify a service");
	}

	if ( defined $service and not exists $hafas_instance->{$service} ) {
		confess("The service '$service' is not supported");
	}

	my $now = DateTime->now( time_zone => $hafas_instance->{$service}{time_zone}
		  // 'Europe/Berlin' );
	my $self = {
		active_service => $service,
		arrivals       => $conf{arrivals},
		cache          => $conf{cache},
		developer_mode => $conf{developer_mode},
		exclusive_mots => $conf{exclusive_mots},
		excluded_mots  => $conf{excluded_mots},
		messages       => [],
		results        => [],
		station        => $conf{station},
		ua             => $ua,
		now            => $now,
		tz_offset      => $now->offset / 60,
	};

	bless( $self, $obj );

	my $req;

	if ( $conf{journey} ) {
		$req = {
			svcReqL => [
				{
					meth => 'JourneyDetails',
					req  => {
						jid         => $conf{journey}{id},
						name        => $conf{journey}{name} // '0',
						getPolyline => $conf{with_polyline} ? \1 : \0,
					},
				}
			],
			%{ $hafas_instance->{$service}{request} }
		};
	}
	elsif ( $conf{journeyMatch} ) {
		$req = {
			svcReqL => [
				{
					meth => 'JourneyMatch',
					req  => {
						date => ( $conf{datetime} // $now )->strftime('%Y%m%d'),
						input    => $conf{journeyMatch},
						jnyFltrL => [
							{
								type  => "PROD",
								mode  => "INC",
								value => $self->mot_mask
							}
						]
					},
				}
			],
			%{ $hafas_instance->{$service}{request} }
		};
	}
	elsif ( $conf{geoSearch} ) {
		$req = {
			svcReqL => [
				{
					cfg  => { polyEnc => 'GPA' },
					meth => 'LocGeoPos',
					req  => {
						ring => {
							cCrd => {
								x => int( $conf{geoSearch}{lon} * 1e6 ),
								y => int( $conf{geoSearch}{lat} * 1e6 ),
							},
							maxDist => -1,
							minDist =>  0,
						},
						locFltrL => [
							{
								type  => "PROD",
								mode  => "INC",
								value => $self->mot_mask
							}
						],
						getPOIs  => \0,
						getStops => \1,
						maxLoc   => $conf{results} // 30,
					}
				}
			],
			%{ $hafas_instance->{$service}{request} }
		};
	}
	elsif ( $conf{locationSearch} ) {
		$req = {
			svcReqL => [
				{
					cfg  => { polyEnc => 'GPA' },
					meth => 'LocMatch',
					req  => {
						input => {
							loc => {
								type => 'S',
								name => $conf{locationSearch},
							},
							maxLoc => $conf{results} // 30,
							field  => 'S',
						},
					}
				}
			],
			%{ $hafas_instance->{$service}{request} }
		};
	}
	else {
		my $date = ( $conf{datetime} // $now )->strftime('%Y%m%d');
		my $time = ( $conf{datetime} // $now )->strftime('%H%M00');

		my $lid;
		if ( $self->{station} =~ m{ ^ [0-9]+ $ }x ) {
			$lid = 'A=1@L=' . $self->{station} . '@';
		}
		else {
			$lid = 'A=1@O=' . $self->{station} . '@';
		}

		my $maxjny   = $conf{results}   // 30;
		my $duration = $conf{lookahead} // -1;

		$req = {
			svcReqL => [
				{
					meth => 'StationBoard',
					req  => {
						type     => ( $conf{arrivals} ? 'ARR' : 'DEP' ),
						stbLoc   => { lid => $lid },
						dirLoc   => undef,
						maxJny   => $maxjny,
						date     => $date,
						time     => $time,
						dur      => $duration,
						jnyFltrL => [
							{
								type  => "PROD",
								mode  => "INC",
								value => $self->mot_mask
							}
						]
					},
				},
			],
			%{ $hafas_instance->{$service}{request} }
		};
	}

	if ( $conf{language} ) {
		$req->{lang} = $conf{language};
	}

	$self->{strptime_obj} //= DateTime::Format::Strptime->new(
		pattern   => '%Y%m%dT%H%M%S',
		time_zone => $hafas_instance->{$service}{time_zone} // 'Europe/Berlin',
	);

	my $json = $self->{json} = JSON->new->utf8;

	# The JSON request is the cache key, so if we have a cache we must ensure
	# that JSON serialization is deterministic.
	if ( $self->{cache} ) {
		$json->canonical;
	}

	$req = $json->encode($req);
	$self->{post} = $req;

	my $url = $conf{url} // $hafas_instance->{$service}{mgate};

	if ( my $salt = $hafas_instance->{$service}{salt} ) {
		if ( $hafas_instance->{$service}{micmac} ) {
			my $mic = md5_hex( $self->{post} );
			my $mac = md5_hex( $mic . $salt );
			$url .= "?mic=$mic&mac=$mac";
		}
		else {
			$url .= '?checksum=' . md5_hex( $self->{post} . $salt );
		}
	}

	if ( $conf{async} ) {
		$self->{url} = $url;
		return $self;
	}

	if ( $conf{json} ) {
		$self->{raw_json} = $conf{json};
	}
	else {
		if ( $self->{developer_mode} ) {
			say "requesting $req from $url";
		}

		my ( $content, $error ) = $self->post_with_cache($url);

		if ($error) {
			$self->{errstr} = $error;
			return $self;
		}

		if ( $self->{developer_mode} ) {
			say decode( 'utf-8', $content );
		}

		$self->{raw_json} = $json->decode($content);
	}

	$self->check_mgate;

	if ( $conf{journey} ) {
		$self->parse_journey;
	}
	elsif ( $conf{journeyMatch} ) {
		$self->parse_journey_match;
	}
	elsif ( $conf{geoSearch} or $conf{locationSearch} ) {
		$self->parse_search;
	}
	else {
		$self->parse_board;
	}

	return $self;
}

sub new_p {
	my ( $obj, %conf ) = @_;
	my $promise = $conf{promise}->new;

	if (
		not(   $conf{station}
			or $conf{journey}
			or $conf{journeyMatch}
			or $conf{geoSearch}
			or $conf{locationSearch} )
	  )
	{
		return $promise->reject(
'station / journey / journeyMatch / geoSearch / locationSearch flag must be passed'
		);
	}

	my $self = $obj->new( %conf, async => 1 );
	$self->{promise} = $conf{promise};

	$self->post_with_cache_p( $self->{url} )->then(
		sub {
			my ($content) = @_;
			$self->{raw_json} = $self->{json}->decode($content);
			$self->check_mgate;
			if ( $conf{journey} ) {
				$self->parse_journey;
			}
			elsif ( $conf{journeyMatch} ) {
				$self->parse_journey_match;
			}
			elsif ( $conf{geoSearch} or $conf{locationSearch} ) {
				$self->parse_search;
			}
			else {
				$self->parse_board;
			}
			if ( $self->errstr ) {
				$promise->reject( $self->errstr, $self );
			}
			else {
				$promise->resolve($self);
			}
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

# }}}
# {{{ Internal Helpers

sub mot_mask {
	my ($self) = @_;

	my $service  = $self->{active_service};
	my $mot_mask = 2**@{ $hafas_instance->{$service}{productbits} } - 1;

	my %mot_pos;
	for my $i ( 0 .. $#{ $hafas_instance->{$service}{productbits} } ) {
		if ( ref( $hafas_instance->{$service}{productbits}[$i] ) eq 'ARRAY' ) {
			$mot_pos{ $hafas_instance->{$service}{productbits}[$i][0] } = $i;
		}
		else {
			$mot_pos{ $hafas_instance->{$service}{productbits}[$i] } = $i;
		}
	}

	if ( my @mots = @{ $self->{exclusive_mots} // [] } ) {
		$mot_mask = 0;
		for my $mot (@mots) {
			if ( exists $mot_pos{$mot} ) {
				$mot_mask |= 1 << $mot_pos{$mot};
			}
			elsif ( $mot =~ m{ ^ \d+ $ }x ) {
				$mot_mask |= 1 << $mot;
			}
		}
	}

	if ( my @mots = @{ $self->{excluded_mots} // [] } ) {
		for my $mot (@mots) {
			if ( exists $mot_pos{$mot} ) {
				$mot_mask &= ~( 1 << $mot_pos{$mot} );
			}
			elsif ( $mot =~ m{ ^ \d+ $ }x ) {
				$mot_mask &= ~( 1 << $mot );
			}
		}
	}

	return $mot_mask;
}

sub post_with_cache {
	my ( $self, $url ) = @_;
	my $cache = $self->{cache};

	if ( $self->{developer_mode} ) {
		say "POST $url $self->{post}";
	}

	if ($cache) {
		my $content = $cache->thaw( $self->{post} );
		if ( $content
			and not $content =~ m{ CGI_NO_SERVER | CGI_READ_FAILED }x )
		{
			if ( $self->{developer_mode} ) {
				say '  cache hit';
			}
			return ( ${$content}, undef );
		}
	}

	if ( $self->{developer_mode} ) {
		say '  cache miss';
	}

	my $reply = $self->{ua}->post(
		$url,
		'Content-Type' => 'application/json',
		Content        => $self->{post}
	);

	if ( $reply->is_error ) {
		return ( undef, $reply->status_line );
	}
	my $content = $reply->content;

	if ($cache) {
		$cache->freeze( $self->{post}, \$content );
	}

	return ( $content, undef );
}

sub post_with_cache_p {
	my ( $self, $url ) = @_;
	my $cache = $self->{cache};

	if ( $self->{developer_mode} ) {
		say "POST $url";
	}

	my $promise = $self->{promise}->new;

	if ($cache) {
		my $content = $cache->thaw( $self->{post} );
		if ($content) {
			if ( $self->{developer_mode} ) {
				say '  cache hit';
			}
			return $promise->resolve( ${$content} );
		}
	}

	if ( $self->{developer_mode} ) {
		say '  cache miss';
	}

	my $headers      = {};
	my $service_desc = $hafas_instance->{ $self->{active_service} };

	if ( $service_desc->{ua_string} ) {
		$headers->{'User-Agent'} = $service_desc->{ua_string};
	}
	if ( my $geoip_service = $service_desc->{geoip_lock} ) {
		if ( my $proxy = $ENV{"HAFAS_PROXY_${geoip_service}"} ) {
			$self->{ua}->proxy->http($proxy);
			$self->{ua}->proxy->https($proxy);
		}
	}
	if ( not $service_desc->{tls_verify} ) {
		$self->{ua}->insecure(1);
	}

	$self->{ua}->post_p( $url, $headers, $self->{post} )->then(
		sub {
			my ($tx) = @_;
			if ( my $err = $tx->error ) {
				$promise->reject(
					"POST $url returned HTTP $err->{code} $err->{message}");
				return;
			}
			my $content = $tx->res->body;
			if ($cache) {
				$cache->freeze( $self->{post}, \$content );
			}
			$promise->resolve($content);
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

sub check_mgate {
	my ($self) = @_;

	if ( $self->{raw_json}{err} and $self->{raw_json}{err} ne 'OK' ) {
		$self->{errstr} = $self->{raw_json}{errTxt}
		  // 'error code is ' . $self->{raw_json}{err};
		$self->{errcode} = $self->{raw_json}{err};
	}
	elsif ( defined $self->{raw_json}{cInfo}{code}
		and $self->{raw_json}{cInfo}{code} ne 'OK'
		and $self->{raw_json}{cInfo}{code} ne 'VH' )
	{
		$self->{errstr}  = 'cInfo code is ' . $self->{raw_json}{cInfo}{code};
		$self->{errcode} = $self->{raw_json}{cInfo}{code};
	}
	elsif ( @{ $self->{raw_json}{svcResL} // [] } == 0 ) {
		$self->{errstr} = 'svcResL is empty';
	}
	elsif ( $self->{raw_json}{svcResL}[0]{err} ne 'OK' ) {
		$self->{errstr}
		  = 'svcResL[0].err is ' . $self->{raw_json}{svcResL}[0]{err};
		$self->{errcode} = $self->{raw_json}{svcResL}[0]{err};
	}

	return $self;
}

sub add_message {
	my ( $self, $json, $is_him ) = @_;

	my $text = $json->{txtN};
	my $code = $json->{code};

	if ($is_him) {
		$text = $json->{text};
		$code = $json->{hid};
	}

	# Some backends use remL for operator information. We don't want that.
	if ( $code eq 'OPERATOR' ) {
		return;
	}

	for my $message ( @{ $self->{messages} } ) {
		if ( $code eq $message->{code} and $text eq $message->{text} ) {
			$message->{ref_count}++;
			return $message;
		}
	}

	my $message = Travel::Status::DE::HAFAS::Message->new(
		json      => $json,
		is_him    => $is_him,
		ref_count => 1,
	);
	push( @{ $self->{messages} }, $message );
	return $message;
}

sub parse_prodL {
	my ($self) = @_;

	my $common = $self->{raw_json}{svcResL}[0]{res}{common};
	return [
		map {
			Travel::Status::DE::HAFAS::Product->new(
				common  => $common,
				product => $_
			)
		} @{ $common->{prodL} }
	];
}

sub parse_search {
	my ($self) = @_;

	$self->{results} = [];

	if ( $self->{errstr} ) {
		return $self;
	}

	my @locL = @{ $self->{raw_json}{svcResL}[0]{res}{locL} // [] };

	if ( $self->{raw_json}{svcResL}[0]{res}{match} ) {
		@locL = @{ $self->{raw_json}{svcResL}[0]{res}{match}{locL} // [] };
	}

	@{ $self->{results} }
	  = map { Travel::Status::DE::HAFAS::Location->new( loc => $_ ) } @locL;

	return $self;
}

sub parse_journey {
	my ($self) = @_;

	if ( $self->{errstr} ) {
		return $self;
	}

	my $prodL = $self->parse_prodL;

	my @locL = map { Travel::Status::DE::HAFAS::Location->new( loc => $_ ) }
	  @{ $self->{raw_json}{svcResL}[0]{res}{common}{locL} // [] };
	my $journey = $self->{raw_json}{svcResL}[0]{res}{journey};
	my @polyline;

	my $poly = $journey->{poly};

	# ÖBB
	if ( $journey->{polyG} and @{ $journey->{polyG}{polyXL} // [] } ) {
		$poly = $self->{raw_json}{svcResL}[0]{res}{common}{polyL}
		  [ $journey->{polyG}{polyXL}[0] ];
	}

	if ($poly) {
		@polyline = decode_polyline( $poly->{crdEncYX} );
		for my $ref ( @{ $poly->{ppLocRefL} // [] } ) {
			my $poly = $polyline[ $ref->{ppIdx} ];
			my $loc  = $locL[ $ref->{locX} ];

			$poly->{name} = $loc->name;
			$poly->{eva}  = $loc->eva;
		}
	}

	$self->{result} = Travel::Status::DE::HAFAS::Journey->new(
		common   => $self->{raw_json}{svcResL}[0]{res}{common},
		prodL    => $prodL,
		locL     => \@locL,
		journey  => $journey,
		polyline => \@polyline,
		hafas    => $self,
	);

	return $self;
}

sub parse_journey_match {
	my ($self) = @_;

	$self->{results} = [];

	if ( $self->{errstr} ) {
		return $self;
	}

	my $prodL = $self->parse_prodL;

	my @locL = map { Travel::Status::DE::HAFAS::Location->new( loc => $_ ) }
	  @{ $self->{raw_json}{svcResL}[0]{res}{common}{locL} // [] };

	my @jnyL = @{ $self->{raw_json}{svcResL}[0]{res}{jnyL} // [] };

	for my $result (@jnyL) {
		push(
			@{ $self->{results} },
			Travel::Status::DE::HAFAS::Journey->new(
				common  => $self->{raw_json}{svcResL}[0]{res}{common},
				prodL   => $prodL,
				locL    => \@locL,
				journey => $result,
				hafas   => $self,
			)
		);
	}
	return $self;
}

sub parse_board {
	my ($self) = @_;

	$self->{results} = [];

	if ( $self->{errstr} ) {
		return $self;
	}

	my $prodL = $self->parse_prodL;

	my @locL = map { Travel::Status::DE::HAFAS::Location->new( loc => $_ ) }
	  @{ $self->{raw_json}{svcResL}[0]{res}{common}{locL} // [] };
	my @jnyL = @{ $self->{raw_json}{svcResL}[0]{res}{jnyL} // [] };

	for my $result (@jnyL) {
		eval {
			push(
				@{ $self->{results} },
				Travel::Status::DE::HAFAS::Journey->new(
					common  => $self->{raw_json}{svcResL}[0]{res}{common},
					prodL   => $prodL,
					locL    => \@locL,
					journey => $result,
					hafas   => $self,
				)
			);
		};
		if ($@) {
			if ( $@ =~ m{Invalid local time for date in time zone} ) {

				# Yes, HAFAS does in fact return invalid times during DST change
				# (as in, it returns 02:XX:XX timestamps when the time jumps from 02:00:00 to 03:00:00)
				# It's not clear what exactly is going wrong where and whether a 2:30 or a 3:30 journey is the correct one.
				# For now, silently discard the affected journeys.
			}
			else {
				warn("Skipping $result->{jid}: $@");
			}
		}
	}
	return $self;
}

# }}}
# {{{ Public Functions

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

	if ( $service and exists $hafas_instance->{$service}{stopfinder} ) {

		my $sf = Travel::Status::DE::HAFAS::StopFinder->new(
			url            => $hafas_instance->{$service}{stopfinder},
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

sub similar_stops_p {
	my ( $self, %opt ) = @_;

	my $service = $self->{active_service};

	if ( $service and exists $hafas_instance->{$service}{stopfinder} ) {
		$opt{user_agent} //= $self->{ua};
		$opt{promise}    //= $self->{promise};
		return Travel::Status::DE::HAFAS::StopFinder->new_p(
			url            => $hafas_instance->{$service}{stopfinder},
			input          => $self->{station},
			user_agent     => $opt{user_agent},
			developer_mode => $self->{developer_mode},
			promise        => $opt{promise},
		);
	}
	return $opt{promise}
	  ->reject("stopfinder not available for backend '$service'");
}

sub station {
	my ($self) = @_;

	if ( $self->{station_info} ) {
		return $self->{station_info};
	}

	my %eva_count;
	my %name_count;
	my %eva_by_name;

	for my $result ( $self->results ) {
		$eva_count{ $result->station_eva } += 1;
		$name_count{ $result->station }    += 1;
		$eva_by_name{ $result->station_eva } = $result->station;
	}

	my @most_frequent_evas = map { $_->[0] } sort { $b->[1] <=> $a->[1] }
	  map { [ $_, $eva_count{$_} ] } keys %eva_count;

	my @most_frequent_names = map { $_->[0] } sort { $b->[1] <=> $a->[1] }
	  map { [ $_, $name_count{$_} ] } keys %name_count;

	my @shortest_names = map { $_->[0] } sort { $a->[1] <=> $b->[1] }
	  map { [ $_, length($_) ] } keys %name_count;

	if ( not @shortest_names ) {
		$self->{station_info} = {};
		return $self->{station_info};
	}

	# The shortest name is typically the most helpful one, e.g. "Wien Hbf" vs. "Wien Hbf Süd (Sonnwendgasse)"
	$self->{station_info} = {
		name  => $shortest_names[0],
		eva   => $eva_by_name{ $shortest_names[0] },
		names => \@most_frequent_names,
		evas  => \@most_frequent_evas,
	};

	return $self->{station_info};
}

sub messages {
	my ($self) = @_;
	return @{ $self->{messages} };
}

sub results {
	my ($self) = @_;
	return @{ $self->{results} };
}

sub result {
	my ($self) = @_;
	return $self->{result};
}

# static
sub get_services {
	my @services;
	for my $service ( sort keys %{$hafas_instance} ) {
		my %desc = %{ $hafas_instance->{$service} };
		$desc{shortname} = $service;
		push( @services, \%desc );
	}
	return @services;
}

# static
sub get_service {
	my ($service) = @_;

	if ( defined $service and exists $hafas_instance->{$service} ) {
		return $hafas_instance->{$service};
	}
	return;
}

sub get_active_service {
	my ($self) = @_;

	if ( defined $self->{active_service} ) {
		return $hafas_instance->{ $self->{active_service} };
	}
	return;
}

# }}}

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

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS is an interface to HAFAS-based
arrival/departure monitors using the mgate.exe interface.

It can report departures/arrivals at a specific station, search for stations,
or provide details about a specific journey. It supports non-blocking operation
via promises.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::HAFAS->new(I<%opt>)

Requests item(s) as specified by I<opt> and returns a new
Travel::Status::DE::HAFAS element with the results.  Dies if the wrong
I<opt> were passed.

I<opt> must contain a HAFAS service identifier:

=over

=item B<service> => I<service> (mandatory)

Request results from I<service>. See B<get_services> (and C<< hafas-m --list
>>) for a list of supported services.

=back

Additionally, I<opt> must contain either a B<station>, B<geoSearch>,
B<locationSearch>, B<journey>, or B<journeyMatch> flag:

=over

=item B<station> => I<station>

Request station board (arrivals or departures) for I<station>, e.g. "Essen HBf" or
"Alfredusbad, Essen (Ruhr)". The station must be specified either by name or by
EVA ID (e.g. 8000080 for Dortmund Hbf).
Results are available via C<< $status->results >>.

=item B<geoSearch> => B<{> B<lat> => I<latitude>, B<lon> => I<longitude> B<}>

Search for stations near I<latitude>, I<longitude>.
Results are available via C<< $status->results >>.

=item B<locationSearch> => I<query>

Search for stations whose name is similar to I<query>.
Results are available via C<< $status->results >>.

=item B<journey> => B<{> B<id> => I<tripid> [, B<name> => I<line> ] B<}>

Request details about the journey identified by I<tripid> and I<line>.
The result is available via C<< $status->result >>.

=item B<journeyMatch> => I<query>

Request journeys that match I<query> (e.g. "ICE 205" or "S 31111").
Results are available via C<< $status->results >>.
In contrast to B<journey>, the results typically only contain a minimal amount
of information: trip ID, train/line identifier, and first and last stop.  There
is no real-time data.

=back



The following optional flags may be set.
Values in brackets indicate flags that are only relevant in certain request
modes, e.g. geoSearch or journey.

=over

=item B<arrivals> => I<bool> (station)

Request arrivals (if I<bool> is true) rather than departures (if I<bool> is
false or B<arrivals> is not specified).

=item B<cache> => I<Cache::File object>

Store HAFAS replies in the provided cache object.  This module works with
real-time data, so the object should be configured for an expiry of one to two
minutes.

=item B<datetime> => I<DateTime object> (station)

Date and time to report for.  Defaults to now.

=item B<excluded_mots> => [I<mot1>, I<mot2>, ...] (geoSearch, station, journeyMatch)

By default, all modes of transport (trains, trams, buses etc.) are returned.
If this option is set, all modes appearing in I<mot1>, I<mot2>, ... will
be excluded. The supported modes depend on B<service>, use
B<get_services> or B<get_service> to get the supported values.

=item B<exclusive_mots> => [I<mot1>, I<mot2>, ...] (geoSearch, station, journeyMatch)

If this option is set, only the modes of transport appearing in I<mot1>,
I<mot2>, ...  will be returned.  The supported modes depend on B<service>, use
B<get_services> or B<get_service> to get the supported values.

=item B<language> => I<language>

Request text messages to be provided in I<language>. Supported languages depend
on B<service>, use B<get_services> or B<get_service> to get the supported
values. Providing an unsupported or invalid value may lead to garbage output.

=item B<lookahead> => I<int> (station)

Request arrivals/departures that occur up to I<int> minutes after the specified datetime.
Default: -1 (do not limit results by time).

=item B<lwp_options> => I<\%hashref>

Passed on to C<< LWP::UserAgent->new >>. Defaults to C<< { timeout => 10 } >>,
pass an empty hashref to call the LWP::UserAgent constructor without arguments.

=item B<results> => I<count> (geoSearch, locationSearch, station)

Request up to I<count> results.
Default: 30.

=item B<with_polyline> => I<bool> (journey)

Request a polyline (series of geo-coordinates) indicating the train's route.

=back

=item my $status_p = Travel::Status::DE::HAFAS->new_p(I<%opt>)

Returns a promise that resolves into a Travel::Status::DE::HAFAS instance
($status) on success and rejects with an error message on failure. If the
failure occured after receiving a response from the HAFAS backend, the rejected
promise contains a Travel::Status::DE::HAFAS instance as a second argument.
This instance can be used e.g. to call similar_stops_p in case of an ambiguous
location specifier. In addition to the arguments of B<new>, the following
mandatory arguments must be set.

=over

=item B<promise> => I<promises module>

Promises implementation to use for internal promises as well as B<new_p> return
value.  Recommended: Mojo::Promise(3pm).

=item B<user_agent> => I<user agent>

User agent instance to use for asynchronous requests. The object must implement
a B<post_p> function. Recommended: Mojo::UserAgent(3pm).

=back

=item $status->errcode

In case of an error in the HAFAS backend, returns the corresponding error code
as string. If no backend error occurred, returns undef.

=item $status->errstr

In case of an error in the HTTP request or HAFAS backend, returns a string
describing it.  If no error occurred, returns undef.

=item $status->results (geoSearch, locationSearch)

Returns a list of stop locations. Each list element is a
Travel::Status::DE::HAFAS::Location(3pm) object.

If no matching results were found or the parser / http request failed, returns
an empty list.

=item $status->results (station)

Returns a list of arrivals/departures.  Each list element is a
Travel::Status::DE::HAFAS::Journey(3pm) object.

If no matching results were found or the parser / http request failed, returns
undef.

=item $status->results (journeyMatch)

Returns a list of Travel::Status::DE::HAFAS::Journey(3pm) object that describe
matching journeys. In general, these objects lack real-time data,
intermediate stops, and more.

=item $status->result (journey)

Returns a single Travel::Status::DE::HAFAS::Journey(3pm) object that describes
the requested journey.

If no result was found or the parser / http request failed, returns undef.

=item $status->messages

Returns a list of Travel::Status::DE::HAFAS::Message(3pm) objects with service
messages. Each message belongs to at least one arrival/departure (station,
journey) or to at least stop alongside its route (journey).

=item $status->station (station)

Returns a hashref describing the departure stations in all requested journeys.
The hashref contains four entries: B<names> (station names), B<name> (most
common name), B<evas> (UIC / EVA IDs), and B<eva> (most common UIC / EVA ID).
These are subject to change.

Note that the most common name and ID may be different from the station for
which departures were requested, as HAFAS uses different identifiers for train
stations, bus stops, and other modes of transit even if they are interlinked.

=item $status->similar_stops

Returns a list of hashrefs describing stops whose name is similar to the one
requested in the constructor's B<station> parameter. Returns nothing if
the active service does not support this feature.
This is most useful if B<errcode> returns 'LOCATION', which means that the
HAFAS backend could not identify the stop.

See Travel::Status::DE::HAFAS::StopFinder(3pm)'s B<results> method for details
on the return value.

=item $status->similar_stops_p(I<%opt>)

Returns a promise resolving to a list of hashrefs describing stops whose name
is similar to the one requested in the constructor's B<station> parameter.
Returns nothing if the active service does not support this feature.  This is
most useful if B<errcode> returns 'LOCATION', which means that the HAFAS
backend could not identify the stop.

See Travel::Status::DE::HAFAS::StopFinder(3pm)'s B<results> method for details
on the resolved values.

If $status has been created using B<new_p>, this function does not require
arguments. Otherwise, the caller must specify B<promise> and B<user_agent>
(see B<new_p> above).

=item $status->get_active_service

Returns a hashref describing the active service when a service is active and
nothing otherwise. The hashref contains the following keys.

=over

=item B<coverage> => I<hashref>

Area in which the service provides near-optimal coverage. Typically, this means
a (nearly) complete list of departures and real-time data. The hashref contains
two optional keys: B<area> (GeoJSON) and B<regions> (list of strings, e.g. "DE"
or "CH-BE").

=item B<geoip_lock> => I<proxy_id>

If present: the service filters requests based on the estimated location of the
requesting IP address, and may return errors or time out when the requesting IP
address does not satisfy its requirements. Set the B<HAFAS_PROXY_>I<proxy_id>
environment variable to a proxy string (e.g. C<< socks://localhost:12345 >>) if
needed to work around this.

=item B<homepage> => I<string>

Homepage URL of the service provider.

=item B<languages> => I<arrayref>

Languages supported by the backend; see the constructor's B<language> argument.

=item B<name> => I<string>

Service name, e.g. Bay Area Rapid Transit or E<Ouml>sterreichische Bundesbahnen.

=item B<mgate> => I<string>

HAFAS backend URL

=item B<productbits> => I<arrayref>

MOT bits supported by the backend. I<arrayref> contains either strings
(one string per mode of transit) or arrayrefs (one string pair per mode of
transit, with the first entry referring to the MOT identifier and the second
one containing a slightly longer description of it).

=item B<time_zone> => I<string> (optional)

The time zone this service reports arrival/departure times in. If this key is
not present, it is safe to assume that it uses Europe/Berlin.

=back

=item Travel::Status::DE::HAFAS::get_services()

Returns an array containing all supported HAFAS services. Each element is a
hashref and contains all keys mentioned in B<get_active_service>.
It also contains a B<shortname> key, which is the service name used by
the constructor's B<service> parameter, e.g. BART or NASA.

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

=back

=head1 BUGS AND LIMITATIONS

Some services are not well-tested.

=head1 SEE ALSO

=over

=item * L<https://dbf.finalrewind.org?hafas=NASA> provides a web frontend to
most of this module's features. Set B<hafas=>I<service> to use a specific
service.

=item * Travel::Routing::DE::HAFAS(3pm) for itineraries.

=item * Travel::Status::DE::DBRIS(3pm) for Deutsche Bahn services.

=back

=head1 AUTHOR

Copyright (C) 2015-2025 Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
