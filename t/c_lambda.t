use strict;
use warnings;
use lib 'lib';
use Program qw(lambda curry list);
use Test::More;

my $code = lambda { return "my params @_"; };
my $r = $code->("X");
is $r, "my params X", "Check paramless lambda parameter passing";

$code = lambda { return "baked in: $_[0], passed: $_[1]" } @{["X"]};
$r = $code->("Y");
is $r, "baked in: X, passed: Y", "Check baked in lambda params plus passed params";

my $lb = lambda { return 1 };
is $lb->(), 1, "Simple lambda syntax";

$lb = lambda {
  my $x = shift;
  return $x;
};
is $lb->(2),2, "Check param passing";
is curry((lambda { $_[0]*$_[0] } 2), lambda { $_[0] + 10})->(), 14, "Check curry + lambda";

done_testing;