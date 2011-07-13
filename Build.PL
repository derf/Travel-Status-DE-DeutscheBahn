#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

Module::Build->new(

	build_requires => {
		'File::Slurp'   => 0,
		'Test::More'    => 0,
		'Test::Compile' => 0,
		'Test::Pod'     => 0,
	},
	module_name => 'Travel::Status::DE::DeutscheBahn',
	license     => 'perl',
	requires    => {
		'perl'            => '5.10.1',
		'Carp'            => 0,
		'Class::Accessor' => '0.16',
		'Getopt::Long'    => 0,
		'List::Util'      => 0,
		'LWP::UserAgent'  => 0,
		'POSIX'           => 0,
		'XML::LibXML'     => '1.70',
	},
	script_files => 'bin/',
	sign         => 1,

)->create_build_script();
