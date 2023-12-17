#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 39;

use Travel::Status::DE::HAFAS;

my $json = JSON->new->utf8->decode( read_file('t/in/DB.ICE23.json') );

my $status = Travel::Status::DE::HAFAS->new(
	service      => 'DB',
	journeyMatch => 'ICE 23',
	json         => $json
);

is( $status->errcode, undef, 'no error code' );
is( $status->errstr,  undef, 'no error string' );

is(
	$status->get_active_service->{name},
	'Deutsche Bahn',
	'active service name'
);

is( scalar $status->results, 1, 'number of results' );

my ($result) = $status->results;

isa_ok( $result, 'Travel::Status::DE::HAFAS::Journey' );

is( $result->name,      'ICE 23',                 'name' );
is( $result->type,      'ICE',                    'type' );
is( $result->type_long, 'Intercity-Express',      'type_long', );
is( $result->class,     1,                        'class' );
is( $result->line,      'ICE 23',                 'line' );
is( $result->line_no,   91,                       'line_no' );
is( $result->id,        '1|196351|0|81|17122023', 'id' );
is( $result->operator,  'DB Fernverkehr AG',      'operator' );

is( scalar $result->route,            2,              'route == 2' );
is( ( $result->route )[0]->loc->name, 'Dortmund Hbf', 'route[0] name' );
is( ( $result->route )[0]->arr,       undef,          'route[0] arr' );
is(
	( $result->route )[0]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 043400',
	'route[0] dep'
);
is( ( $result->route )[1]->loc->name, 'Passau Hbf', 'route[1]' );
is(
	( $result->route )[1]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 122500',
	'route[1] arr'
);
is( ( $result->route )[1]->dep, undef, 'route[1] dep' );

is( scalar $result->route_interesting, 1, 'route_interesting == 1' );
is( ( $result->route_interesting )[0]->loc->name,
	'Dortmund Hbf', 'route_interesting[0]' );

# there is no station, so corresponding accessors must be undef
is( $result->rt_datetime,            undef, 'rt_datetime' );
is( $result->sched_datetime,         undef, 'sched_datetime' );
is( $result->datetime,               undef, 'sched_datetime' );
is( $result->delay,                  undef, 'delay' );
is( $result->is_cancelled,           undef, 'is_cancelled' );
is( $result->is_partially_cancelled, undef, 'is_partially_cancelled' );
is( $result->rt_platform,            undef, 'rt_platform' );
is( $result->sched_platform,         undef, 'sched_platform' );
is( $result->platform,               undef, 'platform' );
is( $result->is_changed_platform,    0,     'is_changed_platform' );
is( $result->load,                   undef, 'load' );
is( $result->station,                undef, 'station' );
is( $result->station_eva,            undef, 'station_eva' );
is( $result->origin,                 undef, 'origin' );
is( $result->destination,            undef, 'destination' );
is( $result->direction,              undef, 'direction' );

is( scalar $result->messages, 0, 'messages' );
