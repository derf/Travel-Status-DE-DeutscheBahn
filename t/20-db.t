#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More tests => 2;

BEGIN {
	use_ok('Travel::Status::DE::DeutscheBahn');
}
require_ok('Travel::Status::DE::DeutscheBahn');
