package Travel::Status::DE::HAFAS::Polyline;

use strict;
use warnings;
use 5.014;

# Adapted from code by Slaven Rezic
#
# Copyright (C) 2009,2010,2012,2017,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/

use parent 'Exporter';
our @EXPORT_OK = qw(decode_polyline);

our $VERSION = '6.21';

# Translated this php script
# <http://unitstep.net/blog/2008/08/02/decoding-google-maps-encoded-polylines-using-php/>
# to perl
sub decode_polyline {
	my ($encoded) = @_;

	my $length = length $encoded;
	my $index  = 0;
	my @points;
	my $lat = 0;
	my $lng = 0;

	while ( $index < $length ) {

		# The encoded polyline consists of a latitude value followed
		# by a longitude value. They should always come in pairs. Read
		# the latitude value first.
		for my $val ( \$lat, \$lng ) {
			my $shift  = 0;
			my $result = 0;

			# Temporary variable to hold each ASCII byte.
			my $b;
			do {
				# The `ord(substr($encoded, $index++))` statement returns
				# the ASCII code for the character at $index. Subtract 63
				# to get the original value. (63 was added to ensure
				# proper ASCII characters are displayed in the encoded
				# polyline string, which is `human` readable)
				$b = ord( substr( $encoded, $index++, 1 ) ) - 63;

				# AND the bits of the byte with 0x1f to get the original
				# 5-bit `chunk. Then left shift the bits by the required
				# amount, which increases by 5 bits each time. OR the
				# value into $results, which sums up the individual 5-bit
				# chunks into the original value. Since the 5-bit chunks
				# were reversed in order during encoding, reading them in
				# this way ensures proper summation.
				$result |= ( $b & 0x1f ) << $shift;
				$shift += 5;
			  }

			  # Continue while the read byte is >= 0x20 since the last
			  # `chunk` was not OR'd with 0x20 during the conversion
			  # process. (Signals the end)
			  while ( $b >= 0x20 );

			# see last paragraph of "Integer Arithmetic" in perlop.pod
			use integer;

        # Check if negative, and convert. (All negative values have the last bit
        # set)
			my $dtmp
			  = ( ( $result & 1 ) ? ~( $result >> 1 ) : ( $result >> 1 ) );

			# Compute actual latitude (resp. longitude) since value is
			# offset from previous value.
			$$val += $dtmp;
		}

		# The actual latitude and longitude values were multiplied by
		# 1e5 before encoding so that they could be converted to a 32-bit
		# integer representation. (With a decimal accuracy of 5 places)
		# Convert back to original values.
		push(
			@points,
			{
				lat => $lat * 1e-5,
				lon => $lng * 1e-5
			}
		);
	}

	return @points;
}

1;
