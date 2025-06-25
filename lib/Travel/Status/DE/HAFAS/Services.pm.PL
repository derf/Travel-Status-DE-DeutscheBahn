#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;
use utf8;
use Data::Dumper;
use Encode      qw(encode);
use File::Slurp qw(read_file write_file);
use JSON;

my $json = JSON->new->utf8;

sub load_instance {
	my ( $path, %opt ) = @_;

	my $data = $json->decode(
		scalar read_file("ext/transport-apis/data/${path}-hafas-mgate.json") );
	my %ret = (
		name       => $data->{name} =~ s{ *[(][^)]+[)]}{}r,
		homepage   => $data->{attribution}{homepage},
		mgate      => $data->{options}{endpoint},
		time_zone  => $data->{timezone},
		languages  => $data->{supportedLanguages},
		tls_verify => $opt{tls_verify} // 1,
		request    => {
			client => $data->{options}{client},
			auth   => $data->{options}{auth},
		},
		coverage => {
			area    => $data->{coverage}{realtimeCoverage}{area},
			regions => $data->{coverage}{realtimeCoverage}{region} // []
		},
	);

	my %bitmask_to_product;
	for my $product ( @{ $data->{options}{products} // [] } ) {
		for my $bitmask ( @{ $product->{bitmasks} // [] } ) {
			$bitmask_to_product{$bitmask} = $product;
		}
	}

	my $skipped = 0;
	for my $bit ( 0 .. 15 ) {
		if ( my $p = $bitmask_to_product{ 2**$bit } ) {
			for ( 1 .. $skipped ) {
				push( @{ $ret{productbits} }, [ "_", undef ] );
			}
			if ( $p->{name} ) {
				push( @{ $ret{productbits} }, [ $p->{id}, $p->{name} ] );
			}
			else {
				push( @{ $ret{productbits} }, $p->{id} );
			}
		}
		else {
			$skipped += 1;
		}
	}

	if ( $data->{options}{ext} ) {
		$ret{request}{ext} = $data->{options}{ext};
	}
	if ( $data->{options}{ver} ) {
		$ret{request}{ver} = $data->{options}{ver};
	}
	elsif ( $data->{options}{version} ) {
		$ret{request}{ver} = $data->{options}{version};
	}

	if ( $opt{geoip_lock} ) {
		$ret{geoip_lock} = $opt{geoip_lock};
	}

	if ( $opt{lang} ) {
		$ret{request}{lang} = $opt{lang};
	}
	if ( $opt{ua_string} ) {
		$ret{ua_string} = $opt{ua_string};
	}
	if ( $opt{ver} ) {
		$ret{request}{ver} = $opt{ver};
	}

	return %ret;
}

# HVV: 500 Can't connect to hvv-app.hafas.de:443 (Name or service not known)

# SNCB: CLIENTVERSION error with default config;
# "HCI Core: Invalid client version" with ver=1.21.

my %hafas_instance = (
	AVV => {
		load_instance(
			'de/avv',
			lang => 'deu',
			ver  => '1.26'
		),
		stopfinder => 'https://auskunft.avv.de/bin/ajax-getstop.exe',
	},
	BART => {
		load_instance(
			'us/bart',
			lang => 'en',
			ver  => '1.40'
		),
		stopfinder => 'https://planner.bart.gov/bin/ajax-getstop.exe',
	},
	BLS => {
		load_instance(
			'ch/bls',
			lang => 'deu',
		),
		stopfinder => 'https://bls.hafas.de/bin/ajax-stopfinder.exe',
	},
	BVG => {
		load_instance( 'de/bvg', lang => 'deu' ),
		stopfinder => 'https://bvg-apps-ext.hafas.de/bin/ajax-getstop.exe',
	},
	CMTA => {
		load_instance(
			'us/cmta',
			lang => 'en',
			ver  => '1.40'
		),
		stopfinder => 'https://capmetro.hafas.cloud/bin/ajax-getstop.exe',
	},
	DB => {
		load_instance('de/db'),
		stopfinder => 'https://reiseauskunft.bahn.de/bin/ajax-getstop.exe',
		salt       => 'bdI8UVj40K5fvxwf',
		languages  => [qw[de en fr es]],
		request    => {
			client => {
				id   => 'DB',
				v    => '20100000',
				type => 'IPH',
				name => 'DB Navigator',
			},
			ext  => 'DB.R22.04.a',
			ver  => '1.78',
			auth => {
				type => 'AID',
				aid  => 'n91dB8Z77MLdoR0K'
			},
			lang => 'deu'
		},
	},
	DSB => { load_instance( 'dk/rejseplanen', lang => 'deu' ), },
	IE  => {
		load_instance(
			'ie/iarnrod-eireann',
			lang => 'en',
			ver  => '1.33'
		),
		stopfinder =>
		  'https://journeyplanner.irishrail.ie/bin/ajax-getstop.exe',
		salt   => 'i5s7m3q9z6b4k1c2',
		micmac => 1,
	},
	KVB        => { load_instance( 'de/kvb', lang => 'deu' ), tls_verify => 0 },
	mobiliteit => { load_instance( 'lu/mobiliteit-lu', lang => 'deu' ) },
	NAHSH      => {
		load_instance('de/nahsh'),
		stopfinder => 'https://nah.sh.hafas.de/bin/ajax-getstop.exe',
	},
	NASA => {
		load_instance( 'de/nasa', lang => 'deu' ),
		stopfinder => 'https://reiseauskunft.insa.de/bin/ajax-getstop.exe',
	},
	NVV => {
		load_instance( 'de/nvv', lang => 'deu' ),
		stopfinder =>
		  'https://auskunft.nvv.de/auskunft/bin/jp/ajax-getstop.exe',
	},
	'ÖBB' => {
		load_instance(
			'at/oebb',
			lang => 'deu',
			ver  => '1.57'
		),
		stopfinder => 'https://fahrplan.oebb.at/bin/ajax-getstop.exe',
	},
	PKP => {
		load_instance( 'pl/pkp', lang => 'pol' ),
		ua_string  => 'Dalvik/2.1.0',
		geoip_lock => 'PKP'
	},
	Resrobot => { load_instance( 'se/resrobot', lang => 'sve' ), },
	RMV      => { load_instance( 'de/rmv',      lang => 'deu' ), },
	RSAG     => { load_instance( 'de/rsag',     lang => 'deu' ), },
	SaarVV   => { load_instance( 'de/saarvv',   lang => 'deu' ), },
	STV      => { load_instance( 'at/stv', lang => 'deu', ver => '1.32' ), },
	TPG      => { load_instance( 'ch/tpg', lang => 'deu', ver => '1.40' ), },
	VBB      => {
		load_instance( 'de/vbb', lang => 'deu' ),
		stopfinder => 'https://fahrinfo.vbb.de/bin/ajax-getstop.exe',
	},
	VBN => {
		load_instance(
			'de/vbn',
			lang => 'deu',
			ver  => '1.42'
		),
		stopfinder => 'https://fahrplaner.vbn.de/hafas/ajax-getstop.exe',
		salt       => 'SP31mBufSyCLmNxp',
		micmac     => 1,
	},
	VMT => {
		load_instance(
			'de/vmt',
			lang => 'deu',
			ver  => '1.34'
		),
		salt   => '7x8d3n2a5m1b3c6z',
		micmac => 1,
	},
	VOS => {
		load_instance(
			'de/vos',
			lang => 'deu',
			ver  => '1.72'
		),
		stopfinder => 'https://fahrplan.vos.info/bin/ajax-getstop.exe',
	},
	ZVV => { load_instance( 'ch/zvv', lang => 'deu' ), },
);

my $perlobj = Data::Dumper->new( [ \%hafas_instance ], ['hafas_instance'] );

my $buf = <<'__EOF__';
package Travel::Status::DE::HAFAS::Services;

# vim:readonly
# This module has been automatically generated
# by lib/Travel/Status/DE/HAFAS/Services.pm.PL.
# Do not edit, changes will be lost.

use strict;
use warnings;
use 5.014;
use utf8;

our $VERSION = '6.21';

# Most of these have been adapted from
# <https://github.com/public-transport/transport-apis> and
# <https://github.com/public-transport/hafas-client/tree/main/p>.
# Many thanks to Jannis R / @derhuerst and all contributors for maintaining
# these resources.

__EOF__

$buf .= 'my ' . $perlobj->Sortkeys(1)->Indent(0)->Dump;

$buf =~ s{\Q\x{d6}\E}{Ö}g;
$buf =~ s{\Q\x{c9}\E}{É}g;
$buf =~ s{\Q\x{f3}\E}{ó}g;
$buf =~ s{\Q\x{f6}\E}{ö}g;
$buf =~ s{\Q\x{fc}\E}{ü}g;

$buf .= <<'__EOF__';

sub get_service_ref {
	return $hafas_instance;
}

sub get_service_map {
	return %{$hafas_instance};
}

1;
__EOF__

write_file( $ARGV[0], { binmode => ':utf8' }, $buf );
