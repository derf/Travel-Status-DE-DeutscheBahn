requires 'Class::Accessor';
requires 'DateTime';
requires 'DateTime::Format::Strptime';
requires 'Getopt::Long';
requires 'JSON';
requires 'List::MoreUtils';
requires 'List::Util';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'POSIX';
requires 'XML::LibXML';

on test => sub {
	requires 'Test::Compile';
	requires 'Test::More';
	requires 'Test::Pod';
};
