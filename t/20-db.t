#!/usr/bin/env perl
use strict;
use warnings;
use 5.020;

use utf8;

use File::Slurp qw(read_file);
use JSON;
use Test::More tests => 106;

use Travel::Status::DE::HAFAS;

my $json
  = JSON->new->utf8->decode(
	read_file('t/in/DB.Berlin Jannowitzbruecke.json') );

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

is( $results[0]->direction, 'Tiergarten, Philharmonie', 'result 0: direction' );

for my $res ( $results[0]->route_end, $results[0]->destination ) {
	is( $res, 'Philharmonie Süd, Berlin', 'result 0: route start/end' );
}

is( scalar $results[0]->route_interesting,
	3, 'result 0: route_interesting: 3 elements' );
is(
	( $results[0]->route_interesting )[0]->loc->name,
	'Alexanderstr., Berlin',
	'result 0: route_interesting 0: name'
);
is(
	( $results[0]->route_interesting )[1]->loc->name,
	'Alexanderplatz (S+U)/Grunerstr., Berlin',
	'result 0: route_interesting 1: name'
);
is(
	( $results[0]->route_interesting )[2]->loc->name,
	'Rotes Rathaus (U), Berlin',
	'result 0: route_interesting 2: name'
);

is( scalar $results[0]->route, 12, 'result 0: route: 12 elements' );
is(
	( $results[0]->route )[0]->loc->name,
	'Alexanderstr., Berlin',
	'result 0: route 0: name'
);
is(
	( $results[0]->route )[1]->loc->name,
	'Alexanderplatz (S+U)/Grunerstr., Berlin',
	'result 0: route 1: name'
);
is(
	( $results[0]->route )[2]->loc->name,
	'Rotes Rathaus (U), Berlin',
	'result 0: route 2: name'
);
is(
	( $results[0]->route )[3]->loc->name,
	'Museumsinsel (U), Berlin',
	'result 0: route 3: name'
);
is(
	( $results[0]->route )[4]->loc->name,
	'Staatsoper, Berlin',
	'result 0: route 4: name'
);
is(
	( $results[0]->route )[5]->loc->name,
	'Unter den Linden (U), Berlin',
	'result 0: route 5: name'
);
is(
	( $results[0]->route )[6]->loc->name,
	'Behrenstr./Wilhelmstr., Berlin',
	'result 0: route 6: name'
);
is(
	( $results[0]->route )[7]->loc->name,
	'Mohrenstr. (U), Berlin',
	'result 0: route 7: name'
);
is(
	( $results[0]->route )[8]->loc->name,
	'Leipziger Str./Wilhelmstr., Berlin',
	'result 0: route 8: name'
);
is(
	( $results[0]->route )[9]->loc->name,
	'Potsdamer Platz [Bus Leipziger Str.] (S+U), Berlin',
	'result 0: route 9: name'
);
is(
	( $results[0]->route )[10]->loc->name,
	'Varian-Fry-Str./Potsdamer Platz, Berlin',
	'result 0: route 10: name'
);
is(
	( $results[0]->route )[11]->loc->name,
	'Philharmonie Süd, Berlin',
	'result 0: route 11: name'
);

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

is( $results[2]->direction, 'Hermannstr. (S+U), Berlin',
	'result 2: direction' );

for my $res ( $results[2]->route_end, $results[2]->destination ) {
	is( $res, 'Hermannstr. (S+U), Berlin', 'result 2: route start/end' );
}

is( scalar $results[2]->route_interesting,
	3, 'result 2: route_interesting: 3 elements' );
is(
	( $results[2]->route_interesting )[0]->loc->name,
	'Heinrich-Heine-Str. (U), Berlin',
	'result 2: route_interesting 0: name'
);
is(
	( $results[2]->route_interesting )[1]->loc->name,
	'Moritzplatz (U), Berlin',
	'result 2: route_interesting 1: name'
);
is(
	( $results[2]->route_interesting )[2]->loc->name,
	'Kottbusser Tor (U), Berlin',
	'result 2: route_interesting 2: name'
);

is( scalar $results[2]->route, 8, 'result 2: route: 8 elements' );
is(
	( $results[2]->route )[0]->loc->name,
	'Heinrich-Heine-Str. (U), Berlin',
	'result 2: route 0: name'
);
is(
	( $results[2]->route )[1]->loc->name,
	'Moritzplatz (U), Berlin',
	'result 2: route 1: name'
);
is(
	( $results[2]->route )[2]->loc->name,
	'Kottbusser Tor (U), Berlin',
	'result 2: route 2: name'
);
is(
	( $results[2]->route )[3]->loc->name,
	'Schönleinstr. (U), Berlin',
	'result 2: route 3: name'
);
is(
	( $results[2]->route )[4]->loc->name,
	'Hermannplatz (U), Berlin',
	'result 2: route 4: name'
);
is(
	( $results[2]->route )[5]->loc->name,
	'Boddinstr. (U), Berlin',
	'result 2: route 5: name'
);
is(
	( $results[2]->route )[6]->loc->name,
	'Leinestr. (U), Berlin',
	'result 2: route 6: name'
);
is(
	( $results[2]->route )[7]->loc->name,
	'Hermannstr. (S+U), Berlin',
	'result 2: route 7: name'
);

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

is( $results[3]->direction, 'Berlin-Spandau (S)', 'result 3: direction' );

for my $res ( $results[3]->route_end, $results[3]->destination ) {
	is( $res, 'Berlin-Spandau (S)', 'result 3: route start/end' );
}

is( scalar $results[3]->route_interesting,
	3, 'result 3: route_interesting: 3 elements' );
is(
	( $results[3]->route_interesting )[0]->loc->name,
	'Berlin Alexanderplatz (S)',
	'result 3: route_interesting 0: name'
);
is(
	( $results[3]->route_interesting )[1]->loc->name,
	'Berlin Hackescher Markt',
	'result 3: route_interesting 1: name'
);
is(
	( $results[3]->route_interesting )[2]->loc->name,
	'Berlin Hbf (S-Bahn)',
	'result 3: route_interesting 2: name'
);

is( scalar $results[3]->route, 16, 'result 3: route: 16 elements' );
is(
	( $results[3]->route )[0]->loc->name,
	'Berlin Alexanderplatz (S)',
	'result 3: route 0: name'
);
is(
	( $results[3]->route )[1]->loc->name,
	'Berlin Hackescher Markt',
	'result 3: route 1: name'
);
is(
	( $results[3]->route )[2]->loc->name,
	'Berlin Friedrichstraße (S)',
	'result 3: route 2: name'
);
is(
	( $results[3]->route )[3]->loc->name,
	'Berlin Hbf (S-Bahn)',
	'result 3: route 3: name'
);
is(
	( $results[3]->route )[4]->loc->name,
	'Berlin Bellevue',
	'result 3: route 4: name'
);
is( ( $results[3]->route )[5]->loc->name,
	'Berlin-Tiergarten', 'result 3: route 5: name' );
is(
	( $results[3]->route )[6]->loc->name,
	'Berlin Zoologischer Garten (S)',
	'result 3: route 6: name'
);
is(
	( $results[3]->route )[7]->loc->name,
	'Berlin Savignyplatz',
	'result 3: route 7: name'
);
is(
	( $results[3]->route )[8]->loc->name,
	'Berlin Charlottenburg (S)',
	'result 3: route 8: name'
);
is(
	( $results[3]->route )[9]->loc->name,
	'Berlin Westkreuz',
	'result 3: route 9: name'
);
is(
	( $results[3]->route )[10]->loc->name,
	'Berlin Messe Süd (Eichkamp)',
	'result 3: route 10: name'
);
is(
	( $results[3]->route )[11]->loc->name,
	'Berlin Heerstraße',
	'result 3: route 11: name'
);
is(
	( $results[3]->route )[12]->loc->name,
	'Berlin Olympiastadion',
	'result 3: route 12: name'
);
is( ( $results[3]->route )[13]->loc->name,
	'Berlin-Pichelsberg', 'result 3: route 17: name' );
is( ( $results[3]->route )[14]->loc->name,
	'Berlin-Stresow', 'result 3: route 14: name' );
is(
	( $results[3]->route )[15]->loc->name,
	'Berlin-Spandau (S)',
	'result 3: route 15: name'
);

is(
	$results[3]->sched_datetime->strftime('%Y%m%d %H%M%S'),
	'20221002 170100',
	'result 3: sched_datetime'
);
