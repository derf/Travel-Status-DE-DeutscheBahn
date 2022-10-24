requires 'Class::Accessor';
requires 'DateTime';
requires 'DateTime::Format::Strptime';
requires 'Digest::MD5';
requires 'Getopt::Long';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';

on test => sub {
	requires 'File::Slurp';
	requires 'Test::Compile';
	requires 'Test::More';
	requires 'Test::Pod';
};
