use strict;
use warnings;

use lib 'lib';
use Test::More;
use Program qw(Program);
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


my $progsource = Program(
	sub {
		return 1;
	},
	sub {
		return $_[0]+7;
	},
);
is_deeply $progsource->('source file'), ['main','t/a_program.t',87], "Check debug info for source code";
is_deeply $fourthprogram->('source file'), ['main','t/a_program.t', 67], "Make sure previous programs point to correct source code lines";

my $sourcecode = $progsource->('src');
$progsource->('store', '/tmp/progsourcetest.pl');
open my $fh, "<", "/tmp/progsourcetest.pl";
my $contents = "";
{
	local $/ = undef;
	$contents = <$fh>;
}
close $fh;
unlink "/tmp/progsourcetest.pl";
undef $fh;
is_deeply $sourcecode, $contents, "Successfully stored and retrieved program source from file";
# Lets try to load it
my $loaded = eval $contents;
is $progsource->('exec'),  $loaded->('exec'), "Loaded program runs identitcally to the original";

$progsource->('store', "/tmp/progsource.pl");

done_testing;
