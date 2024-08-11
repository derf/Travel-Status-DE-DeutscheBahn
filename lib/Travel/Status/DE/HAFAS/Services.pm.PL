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
		name      => $data->{name} =~ s{ *[(][^)]+[)]}{}r,
		homepage  => $data->{attribution}{homepage},
		mgate     => $data->{options}{endpoint},
		time_zone => $data->{timezone},
		languages => $data->{supportedLanguages},
		request   => {
			client => $data->{options}{client},
			auth   => $data->{options}{auth},
		},

		#coverage => {
		#	area => $data->{coverage}{realtimeCoverage}{area},
		#	regions => $data->{coverage}{realtimeCoverage}{region},
		#}
	);

	if ( $opt{lang} ) {
		$ret{request}{lang} = $opt{lang};
	}
	if ( $opt{ver} ) {
		$ret{request}{ver} = $opt{ver};
	}

	if ( $data->{options}{ext} ) {
		$ret{request}{ext} = $data->{options}{ext};
	}
	if ( $data->{options}{ver} ) {
		$ret{request}{ver} = $data->{options}{ver};
	}

	return %ret;
}

my %hafas_instance = (
	AVV => {
		load_instance(
			'de/avv',
			lang => 'deu',
			ver  => '1.26'
		),
		stopfinder  => 'https://auskunft.avv.de/bin/ajax-getstop.exe',
		productbits => [
			[ regio    => 'regional trains' ],
			[ ic_ec    => 'long distance trains' ],
			[ ice      => 'long distance trains' ],
			[ bus      => 'long distance busses' ],
			[ s        => 'sububrban trains' ],
			[ u        => 'underground trains' ],
			[ tram     => 'trams' ],
			[ bus      => 'busses' ],
			[ bus      => 'additional busses' ],
			[ ondemand => 'on-demand services' ],
			[ ferry    => 'maritime transit' ]
		],
	},
	BART => {
		load_instance(
			'us/bart',
			lang => 'en',
			ver  => '1.40'
		),
		stopfinder  => 'https://planner.bart.gov/bin/ajax-getstop.exe',
		productbits => [
			[ _     => undef ],
			[ _     => undef ],
			[ cc    => 'cable cars' ],
			[ regio => 'regional trains' ],
			[ _     => undef ],
			[ bus   => 'busses' ],
			[ ferry => 'maritime transit' ],
			[ bart  => 'BART trains' ],
			[ tram  => 'trams' ],
		],
	},
	BLS => {
		load_instance(
			'ch/bls',
			lang => 'deu',
			ver  => '1.46'
		),
		languages   => [qw[de fr it en]],
		stopfinder  => 'https://bls.hafas.de/bin/ajax-stopfinder.exe',
		productbits => [
			[ ice   => 'long distance trains' ],
			[ ic_ec => 'long distance trains' ],
			[ ir    => 'inter-regio trains' ],
			[ regio => 'regional trains' ],
			[ ferry => 'maritime transit' ],
			[ s     => 'suburban trains' ],
			[ bus   => 'busses' ],
			[ fun   => 'funicular / gondola' ],
			[ _     => undef ],
			[ tram  => 'trams' ],
			[ _     => undef ],
			[ _     => undef ],
			[ car   => 'Autoverlad' ]
		],
	},
	BVG => {
		load_instance( 'de/bvg', lang => 'deu' ),
		stopfinder  => 'https://bvg-apps-ext.hafas.de/bin/ajax-getstop.exe',
		productbits => [qw[s u tram bus]],
	},
	CMTA => {
		load_instance(
			'us/cmta',
			lang => 'en',
			ver  => '1.40'
		),
		stopfinder  => 'https://capmetro.hafas.cloud/bin/ajax-getstop.exe',
		productbits => [
			[ _     => undef ],
			[ _     => undef ],
			[ _     => undef ],
			[ regio => 'MetroRail' ],
			[ _     => undef ],
			[ bus   => 'MetroBus' ],
			[ _     => undef ],
			[ _     => undef ],
			[ _     => undef ],
			[ _     => undef ],
			[ _     => undef ],
			[ _     => undef ],
			[ rapid => 'MetroRapid' ],
		],
	},
	DB => {
		load_instance('de/db'),
		stopfinder    => 'https://reiseauskunft.bahn.de/bin/ajax-getstop.exe',
		productbits   => [qw[ice ic_ec d regio s bus ferry u tram ondemand]],
		productgroups =>
		  [ [qw[ice ic_ec d]], [qw[regio s]], [qw[bus ferry u tram ondemand]] ],
		salt      => 'bdI8UVj40K5fvxwf',
		languages => [qw[de en fr es]],
		request   => {
			client => {
				id   => 'DB',
				v    => '20100000',
				type => 'IPH',
				name => 'DB Navigator',
			},
			ext  => 'DB.R21.12.a',
			ver  => '1.18',
			auth => {
				type => 'AID',
				aid  => 'n91dB8Z77MLdoR0K'
			},
			lang => 'deu'
		},
	},
	IE => {
		load_instance(
			'ie/iarnrod-eireann',
			lang => 'en',
			ver  => '1.33'
		),
		stopfinder =>
		  'https://journeyplanner.irishrail.ie/bin/ajax-getstop.exe',
		productbits => [
			[ _     => undef ],
			[ ic    => 'national trains' ],
			[ _     => undef ],
			[ regio => 'regional trains' ],
			[ dart  => 'DART trains' ],
			[ _     => undef ],
			[ luas  => 'LUAS trams' ],
		],
		salt   => 'i5s7m3q9z6b4k1c2',
		micmac => 1,
	},
	KVB => {
		load_instance( 'de/kvb', lang => 'deu' ),
		productbits => [
			[ s        => 'sub-urban trains' ],
			[ tram     => 'trams' ],
			[ _        => undef ],
			[ bus      => 'buses' ],
			[ regio    => 'regional trains' ],
			[ ic       => 'national trains' ],
			[ _        => undef ],
			[ _        => undef ],
			[ ondemand => 'taxi buses' ]
		],
	},
	NAHSH => {
		load_instance('de/nahsh'),
		stopfinder  => 'https://nah.sh.hafas.de/bin/ajax-getstop.exe',
		productbits => [qw[ice ice ice regio s bus ferry u tram ondemand]],
	},
	NASA => {
		load_instance( 'de/nasa', lang => 'deu' ),
		stopfinder  => 'https://reiseauskunft.insa.de/bin/ajax-getstop.exe',
		productbits => [qw[ice ice regio regio regio tram bus ondemand]],
	},
	NVV => {
		load_instance( 'de/nvv', lang => 'deu' ),
		stopfinder =>
		  'https://auskunft.nvv.de/auskunft/bin/jp/ajax-getstop.exe',
		productbits =>
		  [qw[ice ic_ec regio s u tram bus bus ferry ondemand regio regio]],
	},
	'ÖBB' => {
		load_instance(
			'at/oebb',
			lang => 'deu',
			ver  => '1.57'
		),
		stopfinder  => 'https://fahrplan.oebb.at/bin/ajax-getstop.exe',
		productbits => [
			[ ice_rj => 'long distance trains' ],
			[ sev    => 'rail replacement service' ],
			[ ic_ec  => 'long distance trains' ],
			[ d_n    => 'night trains and rapid trains' ],
			[ regio  => 'regional trains' ],
			[ s      => 'suburban trains' ],
			[ bus    => 'busses' ],
			[ ferry  => 'maritime transit' ],
			[ u      => 'underground' ],
			[ tram   => 'trams' ],
			[ other  => 'other transit services' ]
		],
		productgroups =>
		  [ qw[ice_rj ic_ec d_n], qw[regio s sev], qw[bus ferry u tram other] ],
	},
	VBB => {
		load_instance( 'de/vbb', lang => 'deu' ),
		stopfinder  => 'https://fahrinfo.vbb.de/bin/ajax-getstop.exe',
		productbits => [qw[s u tram bus ferry ice regio]],
	},
	VBN => {
		load_instance(
			'de/vbn',
			lang => 'deu',
			ver  => '1.42'
		),
		stopfinder  => 'https://fahrplaner.vbn.de/hafas/ajax-getstop.exe',
		productbits => [qw[ice ice regio regio s bus ferry u tram ondemand]],
		salt        => 'SP31mBufSyCLmNxp',
		micmac      => 1,
	},
	VOS => {
		load_instance(
			'de/vos',
			lang => 'deu',
			ver  => '1.72'
		),
		stopfinder  => 'https://fahrplan.vos.info/bin/ajax-getstop.exe',
		productbits => [qw[ice ic_ec d regio s bus ferry u tram ondemand]],
	},
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

our $VERSION = '6.04';

# Most of these have been adapted from
# <https://github.com/public-transport/transport-apis> and
# <https://github.com/public-transport/hafas-client/tree/main/p>.
# Many thanks to Jannis R / @derhuerst and all contributors for maintaining
# these resources.

__EOF__

$buf .= 'my ' . $perlobj->Sortkeys(1)->Indent(1)->Dump;

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
