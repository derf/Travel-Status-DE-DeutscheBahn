#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 144;

use Travel::Status::DE::HAFAS;

my $json = JSON->new->utf8->decode( read_file('t/in/DB.ICE23.journey.json') );

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	journey => { id => '1|196351|0|81|17122023' },
	json    => $json
);

is( $status->errcode, undef, 'no error code' );
is( $status->errstr,  undef, 'no error string' );

is(
	$status->get_active_service->{name},
	'Deutsche Bahn',
	'active service name'
);

my $result = $status->result;

isa_ok( $result, 'Travel::Status::DE::HAFAS::Journey' );

is( $result->name,      'ICE 23',                 'name' );
is( $result->type,      'ICE',                    'type' );
is( $result->type_long, 'Intercity-Express',      'type_long', );
is( $result->class,     1,                        'class' );
is( $result->line,      'ICE 23',                 'line' );
is( $result->line_no,   91,                       'line_no' );
is( $result->id,        '1|196351|0|81|17122023', 'id' );
is( $result->operator,  'DB Fernverkehr AG',      'operator' );
is( $result->direction, 'Wien Hbf',               'direction' );

is( scalar $result->route, 21, 'route == 21' );

is( ( $result->route )[0]->loc->name, 'Dortmund Hbf', 'route[0] name' );
is( ( $result->route )[0]->direction, 'Wien Hbf',     'route[0] direction' );
is( ( $result->route )[0]->arr,       undef,          'route[0] arr' );
is( ( $result->route )[0]->rt_arr,    undef,          'route[0] rt_arr' );
is(
	( $result->route )[0]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 043400',
	'route[0] dep'
);
is( ( $result->route )[0]->rt_dep,         undef, 'route[0] rt_dep' );
is( ( $result->route )[0]->arr_delay,      undef, 'route[0] arr_delay' );
is( ( $result->route )[0]->dep_delay,      undef, 'route[0] dep_delay' );
is( ( $result->route )[0]->delay,          undef, 'route[0] delay' );
is( ( $result->route )[0]->load->{FIRST},  1,     'route[0] load 1st' );
is( ( $result->route )[0]->load->{SECOND}, 1,     'route[0] load 2nd' );

is( ( $result->route )[1]->loc->name, 'Bochum Hbf', 'route[1] name' );
is( ( $result->route )[1]->direction, undef,        'route[1] direction' );
is(
	( $result->route )[1]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 044700',
	'route[1] arr'
);
is( ( $result->route )[1]->rt_arr, undef, 'route[1] rt_arr' );
is(
	( $result->route )[1]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 044800',
	'route[1] dep'
);
is( ( $result->route )[1]->rt_dep,         undef, 'route[1] rt_dep' );
is( ( $result->route )[1]->arr_delay,      undef, 'route[1] arr_delay' );
is( ( $result->route )[1]->dep_delay,      undef, 'route[1] dep_delay' );
is( ( $result->route )[1]->delay,          undef, 'route[1] delay' );
is( ( $result->route )[1]->load->{FIRST},  1,     'route[1] load 1st' );
is( ( $result->route )[1]->load->{SECOND}, 1,     'route[1] load 2nd' );

is( ( $result->route )[2]->loc->name, 'Essen Hbf', 'route[2] name' );
is(
	( $result->route )[2]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 045900',
	'route[2] arr'
);
is( ( $result->route )[2]->rt_arr, undef, 'route[2] rt_arr' );
is(
	( $result->route )[2]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 050100',
	'route[2] dep'
);
is( ( $result->route )[2]->rt_dep,         undef, 'route[2] rt_dep' );
is( ( $result->route )[2]->arr_delay,      undef, 'route[2] arr_delay' );
is( ( $result->route )[2]->dep_delay,      undef, 'route[2] dep_delay' );
is( ( $result->route )[2]->delay,          undef, 'route[2] delay' );
is( ( $result->route )[2]->load->{FIRST},  1,     'route[2] load 1st' );
is( ( $result->route )[2]->load->{SECOND}, 1,     'route[2] load 2nd' );

is( ( $result->route )[8]->loc->name, 'Mainz Hbf', 'route[8] name' );
is(
	( $result->route )[8]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 073800',
	'route[8] arr'
);
is( ( $result->route )[8]->rt_arr, undef, 'route[8] rt_arr' );
is(
	( $result->route )[8]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 074000',
	'route[8] dep'
);
is( ( $result->route )[8]->rt_dep,         undef, 'route[8] rt_dep' );
is( ( $result->route )[8]->arr_delay,      undef, 'route[8] arr_delay' );
is( ( $result->route )[8]->dep_delay,      undef, 'route[8] dep_delay' );
is( ( $result->route )[8]->delay,          undef, 'route[8] delay' );
is( ( $result->route )[8]->load->{FIRST},  1,     'route[8] load 1st' );
is( ( $result->route )[8]->load->{SECOND}, 2,     'route[8] load 2nd' );

is(
	( $result->route )[9]->loc->name,
	'Frankfurt(M) Flughafen Fernbf',
	'route[9] name'
);
is(
	( $result->route )[9]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 075900',
	'route[9] arr'
);
is( ( $result->route )[9]->rt_arr, undef, 'route[9] rt_arr' );
is(
	( $result->route )[9]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 080200',
	'route[9] dep'
);
is( ( $result->route )[9]->rt_dep,         undef, 'route[9] rt_dep' );
is( ( $result->route )[9]->arr_delay,      undef, 'route[9] arr_delay' );
is( ( $result->route )[9]->dep_delay,      undef, 'route[9] dep_delay' );
is( ( $result->route )[9]->delay,          undef, 'route[9] delay' );
is( ( $result->route )[9]->load->{FIRST},  undef, 'route[9] load 1st' );
is( ( $result->route )[9]->load->{SECOND}, undef, 'route[9] load 2nd' );

is( ( $result->route )[10]->loc->name, 'Frankfurt(Main)Hbf', 'route[10] name' );
is(
	( $result->route )[10]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 081400',
	'route[10] arr'
);
is( ( $result->route )[10]->rt_arr, undef, 'route[10] rt_arr' );
is(
	( $result->route )[10]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 082100',
	'route[10] dep'
);
is( ( $result->route )[10]->rt_dep,         undef, 'route[10] rt_dep' );
is( ( $result->route )[10]->arr_delay,      undef, 'route[10] arr_delay' );
is( ( $result->route )[10]->dep_delay,      undef, 'route[10] dep_delay' );
is( ( $result->route )[10]->delay,          undef, 'route[10] delay' );
is( ( $result->route )[10]->load->{FIRST},  1,     'route[10] load 1st' );
is( ( $result->route )[10]->load->{SECOND}, 2,     'route[10] load 2nd' );

is( ( $result->route )[12]->loc->name, 'Würzburg Hbf', 'route[12] name' );
is(
	( $result->route )[12]->sched_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 093200',
	'route[12] sched_arr'
);
is(
	( $result->route )[12]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 093300',
	'route[12] arr'
);
is(
	( $result->route )[12]->rt_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 093300',
	'route[12] arr'
);
is(
	( $result->route )[12]->sched_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 093400',
	'route[12] sched_dep'
);
is(
	( $result->route )[12]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 093600',
	'route[12] dep'
);
is(
	( $result->route )[12]->rt_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 093600',
	'route[12] dep'
);
is( ( $result->route )[12]->arr_delay,      1, 'route[12] arr_delay' );
is( ( $result->route )[12]->dep_delay,      2, 'route[12] dep_delay' );
is( ( $result->route )[12]->delay,          2, 'route[12] delay' );
is( ( $result->route )[12]->load->{FIRST},  2, 'route[12] load 1st' );
is( ( $result->route )[12]->load->{SECOND}, 2, 'route[12] load 2nd' );

is( ( $result->route )[13]->loc->name, 'Nürnberg Hbf', 'route[13] name' );
is(
	( $result->route )[13]->sched_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 102700',
	'route[13] sched_arr'
);
is(
	( $result->route )[13]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 102900',
	'route[13] arr'
);
is(
	( $result->route )[13]->rt_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 102900',
	'route[13] arr'
);
is(
	( $result->route )[13]->sched_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 103100',
	'route[13] sched_dep'
);
is(
	( $result->route )[13]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 103300',
	'route[13] dep'
);
is(
	( $result->route )[13]->rt_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 103300',
	'route[13] dep'
);
is( ( $result->route )[13]->arr_delay,      2, 'route[13] arr_delay' );
is( ( $result->route )[13]->dep_delay,      2, 'route[13] dep_delay' );
is( ( $result->route )[13]->delay,          2, 'route[13] delay' );
is( ( $result->route )[13]->load->{FIRST},  3, 'route[13] load 1st' );
is( ( $result->route )[13]->load->{SECOND}, 2, 'route[13] load 2nd' );

is( ( $result->route )[15]->loc->name, 'Plattling', 'route[15] name' );
is(
	( $result->route )[15]->sched_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 115700',
	'route[15] sched_arr'
);
is(
	( $result->route )[15]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 115700',
	'route[15] arr'
);
is(
	( $result->route )[15]->rt_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 115700',
	'route[15] arr'
);
is(
	( $result->route )[15]->sched_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 115900',
	'route[15] sched_dep'
);
is(
	( $result->route )[15]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 115900',
	'route[15] dep'
);
is(
	( $result->route )[15]->rt_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 115900',
	'route[15] dep'
);
is( ( $result->route )[15]->arr_delay,      0, 'route[15] arr_delay' );
is( ( $result->route )[15]->dep_delay,      0, 'route[15] dep_delay' );
is( ( $result->route )[15]->delay,          0, 'route[15] delay' );
is( ( $result->route )[15]->load->{FIRST},  2, 'route[15] load 1st' );
is( ( $result->route )[15]->load->{SECOND}, 2, 'route[15] load 2nd' );

is( ( $result->route )[16]->loc->name, 'Passau Hbf', 'route[16] name' );
is(
	( $result->route )[16]->sched_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 122500',
	'route[16] sched_arr'
);
is(
	( $result->route )[16]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 122700',
	'route[16] arr'
);
is(
	( $result->route )[16]->rt_arr->strftime('%Y%m%d %H%M%S'),
	'20231217 122700',
	'route[16] arr'
);
is(
	( $result->route )[16]->sched_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 122900',
	'route[16] sched_dep'
);
is(
	( $result->route )[16]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 122900',
	'route[16] dep'
);
is(
	( $result->route )[16]->rt_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 122900',
	'route[16] dep'
);
is( ( $result->route )[16]->arr_delay,      2,     'route[16] arr_delay' );
is( ( $result->route )[16]->dep_delay,      0,     'route[16] dep_delay' );
is( ( $result->route )[16]->delay,          0,     'route[16] delay' );
is( ( $result->route )[16]->load->{FIRST},  undef, 'route[16] load 1st' );
is( ( $result->route )[16]->load->{SECOND}, undef, 'route[16] load 2nd' );

is( scalar $result->route_interesting, 3, 'route_interesting == 3' );
is( ( $result->route_interesting )[0]->loc->name,
	'Dortmund Hbf', 'route_interesting[0]' );
is( ( $result->route_interesting )[1]->loc->name,
	'Bochum Hbf', 'route_interesting[1]' );
is( ( $result->route_interesting )[2]->loc->name,
	'Essen Hbf', 'route_interesting[2]' );

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

is( scalar $result->messages, 12, 'messages' );
