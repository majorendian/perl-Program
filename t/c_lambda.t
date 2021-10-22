use strict;
use warnings;
use lib 'lib';
use Program qw(lambda);
use Test::More;

my $code = lambda { return "my params @_"; } ();
my $r = $code->("X");
is $r, "my params X", "Check paramless lambda parameter passing";

$code = lambda { return "baked in: $_[0], passed: $_[1]" } "X";
$r = $code->("Y");
is $r, "baked in: X, passed: Y", "Check baked in lambda params plus passed params";


done_testing;