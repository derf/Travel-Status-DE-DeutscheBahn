#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use Test::More tests => 67;

use Travel::Status::DE::HAFAS;

my $xml = read_file('t/in/DB.Berlin Jannowitzbrücke.xml');

my $status = Travel::Status::DE::HAFAS->new(
	service => 'DB',
	station => 'Berlin Jannowitzbrücke',
	xml     => $xml
);

is( $status->errcode, undef, 'no error code' );
is( $status->errstr,  undef, 'no error string' );

is(
	$status->get_active_service->{name},
	'Deutsche Bahn',
	'active service name'
);

is( scalar $status->results, 73, 'number of results' );

my @results = $status->results;

# Result 0: S-Bahn

is( $results[0]->date, '13.06.2020', 'result 0: date' );
is(
	$results[0]->datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 141700',
	'result 0: datetime'
);
is( $results[0]->delay, 2,     'result 0: delay' );
is( $results[0]->info,  undef, 'result 0: no info' );
ok( !$results[0]->is_cancelled,        'result 0: not cancelled' );
ok( !$results[0]->is_changed_platform, 'result 0: platform not changed' );
is( scalar $results[0]->messages, 0, 'result 0: no messages' );

for my $res ( $results[0]->line, $results[0]->train ) {
	is( $res, 'S      5', 'result 0: line/train' );
}
for my $res ( $results[0]->line_no, $results[0]->train_no ) {
	is( $res, 5, 'result 0: line/train number' );
}

is( $results[0]->operator, undef, 'result 0: no operator' );
is( $results[0]->platform, '4',   'result 0: platform' );

for my $res ( $results[0]->route_end, $results[0]->destination,
	$results[0]->origin )
{
	is( $res, 'Berlin Westkreuz', 'result 0: route start/end' );
}

is( $results[0]->sched_date, '13.06.2020', 'result 0: sched_date' );
is(
	$results[0]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 141500',
	'result 0: sched_datetime'
);
is( $results[0]->sched_time, '14:15', 'result 0: sched_time' );
is( $results[0]->time,       '14:17', 'result 0: time' );
is( $results[0]->type,       'S',     'result 0: type' );

# Result 2: Bus

is( $results[2]->date, '13.06.2020', 'result 2: date' );
is(
	$results[2]->datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 141700',
	'result 2: datetime'
);
is( $results[2]->delay, 0,     'result 2: delay' );
is( $results[2]->info,  undef, 'result 2: no info' );
ok( !$results[2]->is_cancelled,        'result 2: not cancelled' );
ok( !$results[2]->is_changed_platform, 'result 2: platform not changed' );
is( scalar $results[2]->messages, 0, 'result 2: no messages' );

for my $res ( $results[2]->line, $results[2]->train ) {
	is( $res, 'Bus  300', 'result 2: line/train' );
}
for my $res ( $results[2]->line_no, $results[2]->train_no ) {
	is( $res, 300, 'result 2: line/train number' );
}

is( $results[2]->operator, undef, 'result 2: no operator' );
is( $results[2]->platform, undef, 'result 2: no platform' );

for my $res ( $results[2]->route_end, $results[2]->destination,
	$results[2]->origin )
{
	is( $res, 'Warschauer Str. (S+U), Berlin', 'result 2: route start/end' );
}

is( $results[2]->sched_date, '13.06.2020', 'result 2: sched_date' );
is(
	$results[2]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 141700',
	'result 2: sched_datetime'
);
is( $results[2]->sched_time, '14:17', 'result 2: sched_time' );
is( $results[2]->time,       '14:17', 'result 2: time' );
is( $results[2]->type,       'Bus',   'result 2: type' );

# Result 6: U-Bahn

is( $results[6]->date, '13.06.2020', 'result 6: date' );
is(
	$results[6]->datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 142100',
	'result 6: datetime'
);
is( $results[6]->delay, 1,     'result 6: delay' );
is( $results[6]->info,  undef, 'result 6: no info' );
ok( !$results[6]->is_cancelled,        'result 6: not cancelled' );
ok( !$results[6]->is_changed_platform, 'result 6: platform not changed' );
is( scalar $results[6]->messages, 0, 'result 6: no messages' );

for my $res ( $results[6]->line, $results[6]->train ) {
	is( $res, 'U      8', 'result 6: line/train' );
}
for my $res ( $results[6]->line_no, $results[6]->train_no ) {
	is( $res, 8, 'result 6: line/train number' );
}

is( $results[6]->operator, undef, 'result 6: no operator' );
is( $results[6]->platform, undef, 'result 6: no platform' );

for my $res ( $results[6]->route_end, $results[6]->destination,
	$results[6]->origin )
{
	is( $res, 'Paracelsus-Bad (U), Berlin', 'result 6: route start/end' );
}

is( $results[6]->sched_date, '13.06.2020', 'result 6: sched_date' );
is(
	$results[6]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20200613 142000',
	'result 6: sched_datetime'
);
is( $results[6]->sched_time, '14:20', 'result 6: sched_time' );
is( $results[6]->time,       '14:21', 'result 6: time' );
is( $results[6]->type,       'U',     'result 6: type' );
