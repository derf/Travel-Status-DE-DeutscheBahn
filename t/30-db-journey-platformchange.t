#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 30;

use Travel::Status::DE::HAFAS;

my $json = JSON->new->utf8->decode( read_file('t/in/DB.EC392.journey.json') );

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	journey => { id => '1|197782|0|81|17122023' },
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

is( $result->name,      'EC 392',                 'name' );
is( $result->type,      'EC',                     'type' );
is( $result->type_long, 'Eurocity',               'type_long', );
is( $result->class,     2,                        'class' );
is( $result->line,      'EC 392',                 'line' );
is( $result->line_no,   75,                       'line_no' );
is( $result->id,        '1|197782|0|81|17122023', 'id' );
is( $result->operator,  'DB Fernverkehr AG',      'operator' );
is( $result->direction, 'Koebenhavn H',           'direction' );

is( scalar $result->route, 7, 'route == 7' );

is( ( $result->route )[0]->loc->name, 'Hamburg Hbf',  'route[0] name' );
is( ( $result->route )[0]->direction, 'Koebenhavn H', 'route[0] direction' );
is( ( $result->route )[0]->arr,       undef,          'route[0] arr' );
is( ( $result->route )[0]->rt_arr,    undef,          'route[0] rt_arr' );
is(
	( $result->route )[0]->sched_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 145300',
	'route[0] dep'
);
is(
	( $result->route )[0]->rt_dep->strftime('%Y%m%d %H%M%S'),
	'20231217 150300',
	'route[0] dep'
);
is(
	( $result->route )[0]->dep->strftime('%Y%m%d %H%M%S'),
	'20231217 150300',
	'route[0] dep'
);
is( ( $result->route )[0]->arr_delay,      undef,   'route[0] arr_delay' );
is( ( $result->route )[0]->dep_delay,      10,      'route[0] dep_delay' );
is( ( $result->route )[0]->delay,          10,      'route[0] delay' );
is( ( $result->route )[0]->load->{FIRST},  3,       'route[0] load 1st' );
is( ( $result->route )[0]->load->{SECOND}, 3,       'route[0] load 2nd' );
is( ( $result->route )[0]->sched_platform, '12C-F', 'route[0] sched_platform' );
is( ( $result->route )[0]->rt_platform,    '12A-B', 'route[0] rt_platform' );
is( ( $result->route )[0]->platform,       '12A-B', 'route[0] rt_platform' );
ok( ( $result->route )[0]->is_changed_platform,
	'route[0] is_changed_platform' );
