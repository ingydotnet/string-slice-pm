use strict;
use warnings;
use Test::More;

use String::Slice;

my $string = 'x' x 1000;
my $slice = "";

my $return = slice($slice, $string);
is $return, 1, 'Return value is 1';
is length($slice), 1000, 'Length matches original';
is $slice, $string, 'First slice matches string';

$return = slice($slice, $string, 100);
is $return, 1, 'Advance 100 works';
is length($slice), 900, 'Length is rest of string';

$return = slice($slice, $string, -50);
is $return, 1, 'Backup 50 works';
is length($slice), 950, 'Length is rest of string';

$return = slice($slice, $string, 200);
is $return, 1, 'Advance 200 works';
is length($slice), 750, 'Length is rest of string';

$return = slice($slice, $string, 1000);
is $return, 0, 'Advance 950 fails';

my $string2 = "Ingy dot Net";

slice($slice, $string2, 5, 3);
is $slice, 'dot', 'substr slice with length works';

slice($slice, $string2, 4, 5);
is $slice, 'Net', 'Advance matches text';

$return = slice($slice, $string2, -100);
is $return, 0, 'Hop too far back fails';

# Don't have to initialize slice to a string
my $other_slice;
$return = slice($other_slice, $string, 1, 10);
is $return, 1, 'Slicing to an uninitialized slice works';
is($other_slice, ('x' x 10), 'Slice matches text');

done_testing;
