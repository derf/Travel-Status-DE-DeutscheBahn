package Travel::Status::DeutscheBahn;

use strict;
use warnings;
use 5.010;
use base 'Exporter';

use LWP::UserAgent;
use XML::LibXML;

our @EXPORT_OK = ();
my $VERSION = '0.0';

sub new {
	my ($obj, %conf) = @_;
	my $ref = {};

	my @now = localtime(time());

	$ref->{post} = {
		date => $conf{date}
			// sprintf('%d.%d.%d', $now[3], $now[4] + 1, $now[5] + 1900),
		time => $conf{time}
			// sprintf('%d:%d', $now[2], $now[1]),
		input => $conf{station},
		inputef => q{#},
		produtsFilter => '1111101000000000',
		REQTrin_name => q{},
		maxJorneys => 20,
		delayedJourney => undef,
		start => 'Suchen',
		boardType => 'Abfahrt',
		ao => 'yes',
	};
	
	return bless($ref, $obj);
}

sub get {
	my ($self) = @_;
	my $ua = LWP::UserAgent->new();
	my $reply = $ua->post(
			'http://mobile.bahn.de/bin/mobil/bhftafel.exe/dox',
			$self->{post},
		)->content();
	my $tree = XML::LibXML->load_html(
		string => $reply,
		recover => 2,
		suppress_errors => 1,
		suppress_warnings => 1,
	);

	my $xp_element
		= XML::LibXML::XPathExpression->new('//div[@class="sqdetailsDep trow"]');
	my $xp_line = XML::LibXML::XPathExpression->new('./a/span');
	my $xp_dep  = XML::LibXML::XPathExpression->new('./span[1]');

	for my $div (@{$tree->findnodes($xp_element)}) {
		say $div->findnodes($xp_line)->[0]->textContent();
		say $div->findnodes($xp_dep)->[0]->textContent();
		say q{};
	}
}

1;
