package Travel::Status::DE::HAFAS::Product;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.014;

use parent 'Class::Accessor';

our $VERSION = '6.21';

Travel::Status::DE::HAFAS::Product->mk_ro_accessors(
	qw(class line_id line_no name number type type_long operator));

# {{{ Constructor

sub new {
	my ( $obj, %opt ) = @_;

	my $product = $opt{product};
	my $common  = $opt{common};
	my $opL     = $common->{opL};

	# DB:
	# catIn / catOutS eq "IXr" => "ICE X Regio"? regional tickets are generally accepted
	#                          <= does not hold

	my $class    = $product->{cls};
	my $name     = $product->{addName} // $product->{name};
	my $line_no  = $product->{prodCtx}{line};
	my $train_no = $product->{prodCtx}{num};
	my $cat      = $product->{prodCtx}{catOut};
	my $catlong  = $product->{prodCtx}{catOutL};

	# ÖBB, you so silly
	if ( $name and $name =~ m{Zug-Nr} and $product->{nameS} ) {
		$name = $product->{nameS};
	}

	if ( $name and $cat and $name eq $cat and $product->{nameS} ) {
		$name .= ' ' . $product->{nameS};
	}

	if ( defined $train_no and not $train_no ) {
		$train_no = undef;
	}

	if (
		    not defined $line_no
		and defined $product->{prodCtx}{matchId}
		and
		( not defined $train_no or $product->{prodCtx}{matchId} ne $train_no )
	  )
	{
		$line_no = $product->{prodCtx}{matchId};
	}

	my $line_id;
	if ( $product->{prodCtx}{lineId} ) {
		$line_id = lc( $product->{prodCtx}{lineId} =~ s{_+}{-}gr );
	}

	my $operator;
	if ( defined $product->{oprX} ) {
		if ( my $opref = $opL->[ $product->{oprX} ] ) {
			$operator = $opref->{name};
		}
	}

	my $ref = {
		name      => $name,
		number    => $train_no,
		line_id   => $line_id,
		line_no   => $line_no,
		type      => $cat,
		type_long => $catlong,
		class     => $class,
		operator  => $operator,
	};

	bless( $ref, $obj );

	return $ref;
}

# }}}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::HAFAS::Product - Information about a HAFAS product
associated with a journey.

=head1 SYNOPSIS

=head1 VERSION

version 6.21

=head1 DESCRIPTION

Travel::Status::DE::HAFAS::Product describes a product (e.g. train or bus)
associated with a Travel::Status::DE::HAFAS::Journey(3pm) or one of its
stops.

=head1 METHODS

=head2 ACCESSORS

=over

=item $product->class

An integer identifying the the mode of transport class.  Semantics depend on
backend  See Travel::Status::DE::HAFAS(3pm)'s C<< $hafas->get_active_service >>
method.

=item $product->line_id

Line identifier, or undef if it is unknown.
This is a backend-specific identifier, e.g. "7-vrr010-17" for VRR U17.
The format is compatible with L<https://github.com/Traewelling/line-colors>.

=item $product->line_no

Line number, or undef if it is unknown.
The line identifier may be a single number such as "11" (underground train
line U 11), a single word (e.g. "AIR") or a combination (e.g. "SB16").
May also provide line numbers of IC/ICE services.

=item $product->name

Trip or line name, either in a format like "Bus SB16" (Bus line
SB16), "RE 42" (RegionalExpress train 42) or "IC 2901" (InterCity train 2901,
no line information).  May contain extraneous whitespace characters.  Note that
this accessor does not return line information for DB IC/ICE/EC services, even
if it is available. Use B<line_no> for those.

=item $product->number

Trip number (e.g. train number), or undef if it is unknown.

=item $product->type

Type of this product, e.g. "S" for S-Bahn, "RE" for Regional Express
or "STR" for tram / StraE<szlig>enbahn.

=item $product->type_long

Long type of this product, e.g. "S-Bahn" or "Regional-Express".

=item $product->operator

The operator responsible for this product. Returns undef
if the backend does not provide an operator.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Status::DE::HAFAS(3pm).

=head1 AUTHOR

Copyright (C) 2024 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
