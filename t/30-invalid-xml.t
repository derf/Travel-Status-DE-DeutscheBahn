#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use Test::More tests => 2;

use Travel::Status::DE::HAFAS;

my $xml = 'lol';

my $status = Travel::Status::DE::HAFAS->new(
	service => 'NASA',
	station => 'Berlin Jannowitzbrücke',
	xml     => $xml
);

is( scalar $status->results,
	0, 'no results on valid XML with invalid HAFAS data' );

$xml = 'lol<';

$status = Travel::Status::DE::HAFAS->new(
	service => 'NASA',
	station => 'Berlin Jannowitzbrücke',
	xml     => $xml
);

is( scalar $status->results, 0, 'no results on invalid XML' );
