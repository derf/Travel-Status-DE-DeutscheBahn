#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 52;

use Travel::Status::DE::HAFAS;

my $json
  = JSON->new->utf8->decode( read_file('t/in/DB.Berlin Jannowitzbrücke.json') );

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	station => 'Berlin Jannowitzbrücke',
	json    => $json
);

is( $status->errcode, undef, 'no error code' );
is( $status->errstr,  undef, 'no error string' );

is(
	$status->get_active_service->{name},
	'Deutsche Bahn',
	'active service name'
);

is( scalar $status->results, 30, 'number of results' );

my @results = $status->results;

# Result 0: Bus

is(
	$results[0]->datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170500',
	'result 0: datetime'
);
is( $results[0]->delay, 10, 'result 0: delay' );
ok( !$results[0]->is_cancelled,        'result 0: not cancelled' );
ok( !$results[0]->is_changed_platform, 'result 0: platform not changed' );

is( $results[0]->name,      'Bus 300', 'result 0: name' );
is( $results[0]->type,      'Bus',     'result 0: type' );
is( $results[0]->type_long, 'Bus',     'result 0: type_long' );
is( $results[0]->class,     32,        'result 0: class' );
is( $results[0]->line,      'Bus 300', 'result 0: line' );
is( $results[0]->line_no,   '300',     'result 0: line' );
is( $results[0]->number,    '50833',   'result 0: number' );

is( $results[0]->operator, 'Nahreisezug', 'result 0: operator' );
is( $results[0]->platform, undef,         'result 0: platform' );

for my $res ( $results[0]->route_end, $results[0]->destination ) {
	is( $res, 'Philharmonie Süd, Berlin', 'result 0: route start/end' );
}

is(
	$results[0]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 165500',
	'result 0: sched_datetime'
);

# Result 2: U-Bahn

is(
	$results[2]->datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170000',
	'result 2: datetime'
);
is( $results[2]->delay, 0, 'result 2: delay' );
ok( !$results[2]->is_cancelled,        'result 2: not cancelled' );
ok( !$results[2]->is_changed_platform, 'result 2: platform not changed' );

is( $results[2]->name,      'U 8',    'result 2: name' );
is( $results[2]->type,      'U',      'result 2: type' );
is( $results[2]->type_long, 'U-Bahn', 'result 2: type_long' );
is( $results[2]->class,     128,      'result 2: class' );
is( $results[2]->line,      'U 8',    'result 2: line' );
is( $results[2]->line_no,   '8',      'result 2: line' );
is( $results[2]->number,    '20024',  'result 2: number' );

is( $results[2]->operator, 'Nahreisezug', 'result 2: operator' );
is( $results[2]->platform, undef,         'result 2: no platform' );

for my $res ( $results[2]->route_end, $results[2]->destination ) {
	is( $res, 'Hermannstr. (S+U), Berlin', 'result 2: route start/end' );
}

is(
	$results[2]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170000',
	'result 2: sched_datetime'
);

# Result 3: S-Bahn

is(
	$results[3]->datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170100',
	'result 3: datetime'
);
is( $results[3]->delay, 0, 'result 3: delay' );
ok( !$results[3]->is_cancelled,        'result 3: not cancelled' );
ok( !$results[3]->is_changed_platform, 'result 3: platform not changed' );

is( $results[3]->name,      'S 3',    'result 3: name' );
is( $results[3]->type,      'S',      'result 3: type' );
is( $results[3]->type_long, 'S-Bahn', 'result 3: type_long' );
is( $results[0]->class,     32,       'result 3: class' );
is( $results[3]->line,      'S 3',    'result 3: line' );
is( $results[3]->line_no,   '3',      'result 3: line' );
is( $results[3]->number,    '3122',   'result 3: number' );

is( $results[3]->operator, 'S-Bahn Berlin', 'result 3: operator' );
is( $results[3]->platform, 4,               'result 3: platform' );

for my $res ( $results[3]->route_end, $results[3]->destination ) {
	is( $res, 'Berlin-Spandau (S)', 'result 3: route start/end' );
}

is(
	$results[3]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170100',
	'result 3: sched_datetime'
);
