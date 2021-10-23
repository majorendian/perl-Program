use strict;
use warnings;
use lib 'lib';
use Program qw(RulesLinearRandom);
use Test::More;

my $rules = RulesLinearRandom(
  4,
  1 => [1,2],
  2 => [2,3],
  3 => [3,4],
  4 => [4,1]
);
my $vec = $rules->();
is ref($vec), "ARRAY", "Check if we got an array";
is scalar(@$vec), 4, "Check size of returned array";

note "Vector value";
note explain $vec;
# Check proper ruleset
ok(($$vec[0] == 1 or $$vec[0] == 2), "Value at index 0 is either 1 or 2");
ok(($$vec[1] == 2 or $$vec[1] == 3), "Value at index 1 is either 2 or 3");
ok(($$vec[2] == 3 or $$vec[2] == 4), "Value at index 2 is either 3 or 4");
ok(($$vec[3] == 4 or $$vec[3] == 1), "Value at index 3 is either 4 or 1");

done_testing;