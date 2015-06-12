use strict;
use warnings;
use Test::More;

use Benchmark qw(timethese);
use String::Slice;

if ($ENV{PERL_STRING_SLICE_BENCHMARK}) {
    my $count = shift || 1000;
    my $blocks  = shift || 10;

    my ($string, $string2, $utf8_string, $utf8_string2);
    $string = $string2 = 'o' x 1024 x $blocks;
    {
        use utf8;
        $utf8_string = $utf8_string2 = 'ö' x 1024 x $blocks;
    }

    my $slice = '';
    my $var = 0;

    timethese($count, {
        'substr' => sub {
            # substr 10 chars at a time:
            for (my $i = 0; $i < length($string2) - 10; $i += 10) {
            if (substr($string2, $i)) { $var++ }
            }
        },
        'slice' => sub {
            # slice 10 chars at a time:
            for (my $i = 0; $i < length($string) - 10; $i += 10) {
            if (slice($slice, $string, $i)) { $var++ }
            }
        },
        'substr_utf8' => sub {
            # substr 10 chars at a time:
            for (my $i = 0; $i < length($utf8_string2) - 10; $i += 10) {
            if (substr($utf8_string2, $i)) { $var++ }
            }
        },
        'slice_utf8' => sub {
            # slice 10 chars at a time:
            for (my $i = 0; $i < length($utf8_string) - 10; $i += 10) {
            if (slice($slice, $utf8_string, $i)) { $var++ }
            }
        },
    });
}
else {
  diag "env PERL_STRING_SLICE_BENCHMARK not set";
}

pass 'Just a benchmarking test';
done_testing;
