use strict;
use warnings;

use lib 'lib';
use Test::More tests => 10;
use Program;
$Program::DEBUG = 1;

my $program = Program('myprogram',
	sub {
		return 4;
	},
	sub {
		return 2*$_[0];
	},
	sub {
		return 3*$_[0];
	},
);

ok $program->('id') eq "myprogram", "Id of first program is 'myprogram'";
ok $program->('index') == 0, "First program index is 0";
like $program->("help"),qr/program.*?query :/s, "General program help is present";
like $program->(),qr/program.*?query :/s, "General program help is present for `undef` query";
cmp_ok $program->('ni'),'==',1, "Next program index is 1";
my $programcode = $program->('program');
ok $programcode->() == 24, "'myprogram' output equals 24";

my $secondprogram = Program(
	sub {
		my $value = { a => 1, b => 2};
		return $value;
	},
	sub {
		my $prev_val = shift;
		$prev_val->{a} *= 10;
		return $prev_val;
	},
	sub {
		my $v = shift;
		$v->{c} = 3;
		return $v;
	}
);
push @{$secondprogram->('seq')}, sub { my $lv = shift; $lv->{c}++; return $lv;};
is_deeply $secondprogram->('program')->(), { a => 10, b => 2, c => 4}, "Second program result";

my $thirdprog = Program(
	$secondprogram->('program'),
	sub {
		my $h = shift;
		$h->{a} += 5;
		$h->{b} *= 2;
		$h->{c}--;
		return $h;
	}
);
is_deeply $thirdprog->('exec'), { a => 15, b => 4, c => 3 }, "Third program with second program as subprogram";
my $fourthprogram = Program(
	$thirdprog->('program'),
	sub {
		my $h = shift;
		$h->{d} = 't';
		return $h;
	},
);
is_deeply $fourthprogram->('exec'), { a => 15, b => 4, c => 3, d => 't'}, "Program composition with program re-use";
my $fifthprog = Program(
	sub {
		my $h = { a => 9, b => 8, c => 0};
		return $h;
	},
	$thirdprog->('sub',1),
	$fourthprogram->('sub',1)
);
is_deeply $fifthprog->('exec'), { a => 14, b => 16, c => -1, d => 't'}, 'Program sequence re-use';
done_testing;
