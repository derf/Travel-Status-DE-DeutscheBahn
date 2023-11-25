#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

Module::Build->new(

	build_requires => {
		'Test::Compile' => 0,
		'Test::More'    => 0,
		'Test::Pod'     => 0,
	},
	configure_requires => {
		'Module::Build' => 0.40,
	},
	module_name => 'Travel::Status::DE::DeutscheBahn',
	license     => 'perl',
	requires    => {
		'perl'                       => '5.14.0',
		'Carp'                       => 0,
		'Class::Accessor'            => '0.16',
		'DateTime'                   => 0,
		'DateTime::Format::Strptime' => 0,
		'Digest::MD5'                => 0,
		'Getopt::Long'               => 0,
		'JSON'                       => 0,
		'List::MoreUtils'            => 0,
		'List::Util'                 => 0,
		'LWP::UserAgent'             => 0,
		'LWP::Protocol::https'       => 0,
		'Scalar::Util'               => 0,
	},
	script_files  => 'bin/',
	sign          => 1,
	test_requires => { 'File::Slurp' => 0 },
	meta_merge    => {
		resources => {
			repository =>
			  'https://github.com/derf/Travel-Status-DE-DeutscheBahn'
		}
	},
)->create_build_script();
