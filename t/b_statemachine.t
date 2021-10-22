use strict;
use warnings;

use lib 'lib';
use Program qw/Program StateMachine/;
use Test::More;

{
  my $outsidevar = 0;

  my $prog1 = Program(
    sub {
      print "Hello ";
      return 2;
    }
  );

  my $prog2 = Program(
    sub {
      print "World\n";
      $outsidevar++;
      return 1 if $outsidevar < 5;
      return 0; # State machine stops cleanly with code 0
    }
  );
  my $sm = StateMachine('digit', [$prog1, $prog2]);
  my $exit;
  my $memfile;
  open my $memfh, ">", \$memfile;
  my $origfh = select $memfh;
  eval "\$exit = \$sm->();"; # should just loop 5 times
  select $origfh;
  close $memfh;
  is $exit, 0, "SM Exited cleanly";
  is_deeply $memfile, <<CMP, "Check correct output from SM";
Hello World
Hello World
Hello World
Hello World
Hello World
CMP
}
{
  my $prog1 = Program(
    sub {
      my $state = shift; # This is a hashref
      my $x = 1;
      $state->{r} = $x*2 unless exists $state->{r};
      $state;
    },
    sub{
      my $state = shift;
      $state->{r} += 10;
      $state;
    }
  );
  my $prog2 = Program(
    sub {
      my $state = shift;
      $state->{r} += 1;
      $state;
    },
    sub{
      my $state = shift;
      if($state->{r} > 1000){
        $state->{state} = 0;
      }
      $state;
    }
  );
  my $sm = StateMachine('hash', [$prog1, $prog2]);
  my $result = $sm->();
  ok $result->{r} > 1000, "SM 2 Longer iteration";
}
{
  my $prog1 = Program(
    sub {
      print "State 1\n";
      return 3;
    }
  );
  my $prog2 = Program(
    sub {
      print "State 2\n";
      return 0;
    }
  );
  my $prog3 = Program(
    sub {
      print "State 3\n";
      return 2;
    }
  );
  my $mem;
  open my $fh, ">", \$mem;
  my $orig = select $fh;
  my $sm = StateMachine('digit', [$prog1, $prog2, $prog3]);
  $sm->();
  close $fh;
  select $orig;
  is_deeply $mem, "State 1\nState 3\nState 2\n", "State switching";

}

done_testing;