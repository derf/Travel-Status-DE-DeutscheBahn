#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use Test::More tests => 1;

use Travel::Status::DE::HAFAS;

my $xml = 'lol';

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	station => 'Berlin Jannowitzbrücke',
	xml => $xml
);

is (scalar $status->results, 0, 'no results on invalid input');
