#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 36;

use Travel::Status::DE::HAFAS;

my $json = JSON->new->utf8->decode( read_file('t/in/DB.ICE615.journey.json') );

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	journey => { id => '1|160139|0|81|17122023' },
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

is( $result->name,      'ICE 615',                'name' );
is( $result->type,      'ICE',                    'type' );
is( $result->type_long, 'Intercity-Express',      'type_long', );
is( $result->class,     1,                        'class' );
is( $result->line,      'ICE 615',                'line' );
is( $result->line_no,   42,                       'line_no' );
is( $result->id,        '1|160139|0|81|17122023', 'id' );
is( $result->operator,  'DB Fernverkehr AG',      'operator' );
is( $result->direction, 'München Hbf',            'direction' );

is( scalar $result->route, 19, 'route == 19' );

is( ( $result->route )[0]->loc->name, 'Hamburg-Altona', 'route[0] name' );
is( ( $result->route )[0]->direction, 'München Hbf',    'route[0] direction' );

is( ( $result->route )[4]->loc->name, 'Bremen Hbf', 'route[4] name' );
is(
	( $result->route )[4]->direction,
	'Frankfurt(M) Flughafen Fernbf',
	'route[4] direction'
);

is( ( $result->route )[5]->loc->name, 'Osnabrück Hbf', 'route[5] name' );
is( ( $result->route )[5]->direction, 'München Hbf',   'route[5] direction' );

is( ( $result->route )[16]->loc->name, 'Augsburg Hbf', 'route[16] name' );
is(
	( $result->route )[16]->arr->strftime('%Y%m%d %H%M%S'),
	'20231217 235300',
	'route[16] arr'
);
is( ( $result->route )[16]->rt_arr, undef, 'route[16] rt_arr' );
is(
	( $result->route )[16]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 235500',
	'route[16] dep'
);
is( ( $result->route )[16]->rt_dep,    undef, 'route[16] rt_dep' );
is( ( $result->route )[16]->arr_delay, undef, 'route[16] arr_delay' );
is( ( $result->route )[16]->dep_delay, undef, 'route[16] dep_delay' );
is( ( $result->route )[16]->delay,     undef, 'route[16] delay' );

is( ( $result->route )[17]->loc->name, 'München-Pasing', 'route[17] name' );
is(
	( $result->route )[17]->arr->strftime('%Y%m%d %H%M%S'),
	'20231218 001700',
	'route[17] arr'
);
is( ( $result->route )[17]->rt_arr,    undef, 'route[17] rt_arr' );
is( ( $result->route )[17]->dep,       undef, 'route[17] dep' );
is( ( $result->route )[17]->rt_dep,    undef, 'route[17] rt_dep' );
is( ( $result->route )[17]->arr_delay, undef, 'route[17] arr_delay' );
is( ( $result->route )[17]->dep_delay, undef, 'route[17] dep_delay' );
is( ( $result->route )[17]->delay,     undef, 'route[17] delay' );
