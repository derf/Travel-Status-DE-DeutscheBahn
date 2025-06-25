package Travel::Status::DE::HAFAS::StopFinder;

use strict;
use warnings;
use 5.014;
use utf8;

use Carp   qw(confess);
use Encode qw(decode);
use JSON;
use LWP::UserAgent;

our $VERSION = '6.21';

# {{{ Constructors

sub new {
	my ( $obj, %conf ) = @_;

	my $lang = $conf{language} // 'd';
	my $ua   = $conf{ua};

	if ( not $ua and not $conf{async} ) {
		my %lwp_options = %{ $conf{lwp_options} // { timeout => 10 } };
		$ua = LWP::UserAgent->new(%lwp_options);
		$ua->env_proxy;
	}

	my $reply;

	if ( not $conf{input} ) {
		confess('You need to specify an input value');
	}
	if ( not $conf{url} ) {
		confess('You need to specify a URL');
	}

	my $ref = {
		developer_mode => $conf{developer_mode},
		post           => {
			getstop             => 1,
			REQ0JourneyStopsS0A => 255,
			REQ0JourneyStopsS0G => $conf{input},
		},
	};

	bless( $ref, $obj );

	if ( $conf{async} ) {
		return $ref;
	}

	my $url = $conf{url} . "/${lang}n";

	$reply = $ua->post( $url, $ref->{post} );

	if ( $reply->is_error ) {
		$ref->{errstr} = $reply->status_line;
		return $ref;
	}

	$ref->{raw_reply} = $reply->decoded_content;

	$ref->{raw_reply} =~ s{ ^ SLs [.] sls = }{}x;
	$ref->{raw_reply} =~ s{ ; SLs [.] showSuggestion [(] [)] ; $ }{}x;

	if ( $ref->{developer_mode} ) {
		say $ref->{raw_reply};
	}

	$ref->{json} = from_json( $ref->{raw_reply} );

	return $ref;
}

sub new_p {
	my ( $obj, %conf ) = @_;
	my $promise = $conf{promise}->new;

	if ( not $conf{input} ) {
		return $promise->reject('You need to specify an input value');
	}
	if ( not $conf{url} ) {
		return $promise->reject('You need to specify a URL');
	}

	my $self = $obj->new( %conf, async => 1 );
	$self->{promise} = $conf{promise};

	my $lang = $conf{language} // 'd';
	my $url  = $conf{url} . "/${lang}n";
	$conf{user_agent}->post_p( $url, form => $self->{post} )->then(
		sub {
			my ($tx) = @_;
			if ( my $err = $tx->error ) {
				$promise->reject(
					"POST $url returned HTTP $err->{code} $err->{message}");
				return;
			}
			my $content = $tx->res->body;

			$self->{raw_reply} = $content;

			$self->{raw_reply} =~ s{ ^ SLs [.] sls = }{}x;
			$self->{raw_reply} =~ s{ ; SLs [.] showSuggestion [(] [)] ; $ }{}x;

			if ( $self->{developer_mode} ) {
				say $self->{raw_reply};
			}

			$self->{json} = from_json( $self->{raw_reply} );

			$promise->resolve( $self->results );
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

# }}}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub results {
	my ($self) = @_;

	$self->{results} = [];

	for my $result ( @{ $self->{json}->{suggestions} } ) {
		if ( $result->{typeStr} eq '[Bhf/Hst]' ) {
			push(
				@{ $self->{results} },
				{
					name => decode( 'iso-8859-15', $result->{value} ),
					id   => $result->{extId}
				}
			);
		}
	}

	return @{ $self->{results} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::StopFinder - Interface to HAFAS-based online stop
finder services

=head1 SYNOPSIS

	use Travel::Status::DE::HAFAS::StopFinder;

	my $sf = Travel::Status::DE::HAFAS::StopFinder->new(
		url => 'https://reiseauskunft.bahn.de/bin/ajax-getstop.exe',
		input => 'Borbeck',
	);

	if (my $err = $sf->errstr) {
		die("Request error: ${err}\n");
	}

	for my $candidate ($sf->results) {
		printf("%s (%s)\n", $candidate->{name}, $candidate->{id});
	}

=head1 VERSION

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::StopFinder is an interface to the stop finder
service of HAFAS based arrival/departure monitors, for instance the one
available at L<https://reiseauskunft.bahn.de/bin/ajax-getstop.exe/dn>.

It takes a string (usually a location or station name) and reports all
stations and stops which are lexically similar to it.

StopFinder typically gives less coarse results than
Travel::Status::DE::HAFAS(3pm)'s locationSearch method. However, it is unclear
whether HAFAS instances will continue supporting it in the future.

=head1 METHODS

=over

=item my $stopfinder = Travel::Status::DE::HAFAS::StopFinder->new(I<%opts>)

Looks up stops as specified by I<opts> and teruns a new
Travel::Status::DE::HAFAS::StopFinder element with the results.  Dies if the
wrong I<opts> were passed.

Supported I<opts> are:

=over

=item B<input> => I<string>

string to look up, e.g. "Borbeck" or "Koeln Bonn Flughafen". Mandatory.

=item B<url> => I<url>

Base I<url> of the stop finder service, without the language and mode
suffix ("/dn" and similar). Mandatory. See Travel::Status::DE::HAFAS(3pm)'s
B<get_services> method for a list of URLs.

=item B<language> => I<language>

Set language. Accepted arguments are B<d>eutsch, B<e>nglish, B<i>talian and
B<n> (dutch), depending on the used service.

It is unknown if this option has any effect.

=item B<lwp_options> => I<\%hashref>

Passed on to C<< LWP::UserAgent->new >>. Defaults to C<< { timeout => 10 } >>,
you can use an empty hashref to override it.

=back

=item my $stopfinder_p = Travel::Status::DE::HAFAS::StopFinder->new_p(I<%opt>)

Return a promise that resolves into a list of
Travel::Status::DE::HAFAS::StopFinder results ($stopfinder->results) on success
and rejects with an error message ($stopfinder->errstr) on failure. In addition
to the arguments of B<new>, the following mandatory arguments must be set.

=over

=item B<promise> => I<promises module>

Promises implementation to use for internal promises as well as B<new_p> return
value.  Recommended: Mojo::Promise(3pm).

=item B<user_agent> => I<user agent>

User agent instance to use for asynchronous requests. The object must implement
a B<post_p> function. Recommended: Mojo::UserAgent(3pm).

=back

=item $stopfinder->errstr

In case of an error in the HTTP request, returns a string describing it.  If
no error occurred, returns undef.

=item $stopfinder->results

Returns a list of stop candidates. Each list element is a hash reference. The
hash keys are B<id> (IBNR / EVA / UIC station code) and B<name> (stop name).
Both can be used as input for the Travel::Status::DE::HAFAS(3pm) constructor.

If no matching results were found or the parser / HTTP request failed, returns
the empty list.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * LWP::UserAgent(3pm)

=item * JSON(3pm)

=back

=head1 BUGS AND LIMITATIONS

Unknown.

=head1 SEE ALSO

Travel::Status::DE::HAFAS(3pm).

=head1 AUTHOR

Copyright (C) 2015-2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
