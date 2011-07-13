#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use File::Slurp qw(slurp);
use Test::More tests => 96;

BEGIN {
	use_ok('Travel::Status::DE::DeutscheBahn');
}
require_ok('Travel::Status::DE::DeutscheBahn');

my $html = slurp('t/in/essen.html');

my $status = Travel::Status::DE::DeutscheBahn->new_from_html(html => $html);

isa_ok($status, 'Travel::Status::DE::DeutscheBahn');
can_ok($status, qw(results));

my @departures = $status->results;

for my $departure (@departures) {
	isa_ok($departure, 'Travel::Status::DE::DeutscheBahn::Result');
	can_ok($departure, qw(route_end destination origin info platform route
	route_raw time train));
}

is($departures[0]->time, '19:21', 'first result: time ok');
is($departures[0]->train, 'RE 10228', 'first result: train ok');
is($departures[0]->destination, 'Duisburg Hbf', 'first result: destination ok');
is($departures[0]->platform, '2', 'first result: platform ok');
is($departures[0]->delay, 0, 'first result: delay ok');

is($departures[-1]->time, '20:18', 'last result: time ok');
is($departures[-1]->train, 'S 6', 'last result: train ok');
is($departures[-1]->platform, '12', 'last result: platform ok');

is($departures[8]->time, '19:31', '9th result: time ok');
is($departures[8]->train, 'NWB75366', '9th result: train ok');
is($departures[8]->info_raw, 'k.A.', '9th result: info_raw ok');
is($departures[8]->info, q{}, '9th result: info ok');
is($departures[8]->delay, undef, '9th result: delay ok');

is($departures[15]->delay, 15, '16th result: delay ok');

is_deeply([$departures[8]->route],
	['Essen-Borbeck', 'Bottrop Hbf', 'Gladbeck West', 'Gladbeck-Zweckel',
	'Feldhausen', 'Dorsten', 'Hervest-Dorsten', 'Deuten', 'Rhade',
	'Marbeck-Heiden', 'Borken(Westf)'], '9th result: route ok');

is_deeply([$departures[5]->route_interesting(3)],
	['Essen-Steele', 'Essen-Steele Ost', 'Bochum'],
	'6th result: route_interesting(3) ok');

is_deeply([$departures[7]->route_interesting(3)],
	['Wattenscheid', 'Bochum', 'Dortmund'],
	'8th result: route_interesting(3) ok');

is_deeply([$departures[10]->route_interesting(5)],
	[qw[Wattenscheid Bochum Witten Hagen]],
	'11th result: route_interesting(5) ok');
