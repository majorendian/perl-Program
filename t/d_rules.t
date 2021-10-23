use strict;
use warnings;
use lib 'lib';
use Program qw(RulesLinearRandom randomchoice RulesLinear funcall);
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
ok(($$vec[0] == 1 || $$vec[0] == 2), "Value at index 0 is either 1 or 2");
ok(($$vec[1] == 2 || $$vec[1] == 3), "Value at index 1 is either 2 or 3");
ok(($$vec[2] == 3 || $$vec[2] == 4), "Value at index 2 is either 3 or 4");
ok(($$vec[3] == 4 || $$vec[3] == 1), "Value at index 3 is either 4 or 1");

my @a = qw(1 2 3 4 5);
my $choice = randomchoice(@a);
ok($choice >= 1 && $choice <= 5, "randomchoice function check");

$rules = RulesLinear(
  0 => [[4],[1]], # NOTE: 0 is 'preceeded' by 4, otherwise we cannot satisfy the simple loop rule
  1 => [[0],[2]],
  2 => [[1],[3]],
  3 => [[2],[4]],
  4 => [[3],[0]]
);
# Doc: Linear rules are made out of valid 'preceeding' integers
# and valid 'follow-up' integers. If the rule cannot be satisfied
# 'undef' remains in its place

my $result = funcall $rules;
note "Rules result";
note explain $result;

my @cmp = ();
my $next = $result->[0];
push @cmp, $next;
for(@$result){
  $next++;
  if($_ == 4){
    $next = 0;
  }
  push @cmp, $next;
}
pop @cmp;
is_deeply $result, \@cmp, "Compare simple increment ruleset";

done_testing;