package Program;

use 5.032001;
use strict;
use warnings;

require Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);


our @EXPORT_OK = (
	qw(list curry in funcall randomchoice RulesLinear Program StateMachine Machine RulesLinearRandom loadProgram genCmdSub lambda subroutine)
 );
 
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

our @EXPORT = qw(
);

our $DEBUG = 0;
our $VERSION = '0.08';

use strict;
use warnings FATAL => qw(all);

# Dependency packages
use Carp qw(cluck confess);
use List::Util qw(min max reduce uniq uniqint any all none first);
use Data::Dumper;

sub genCmdSub(&$;$){
	my ($codeblock, $regex, $name) = @_;
	return sub {
		my $input_line = shift;
		if(defined $input_line && $input_line =~ /$regex/){
			my @params = map { substr($input_line, $-[$_], $+[$_] - $-[$_]) } (1 .. @--1);
			return $codeblock->(@params);
		}else{
			return -1;
		}
	};
}

sub lambda(&;@){
	my ($code, @params) = @_;
	return sub {
		my @allparams = (@params, @_);
		$code->(@allparams);
	};
}

sub Program(@){
	my $sourcefile = [caller];
	my $getsrccode = lambda { ___src($_[0], $_[1]) } $sourcefile->[1], $sourcefile->[2];
	my $progname = shift;
	my $extensions_help = ""; # Variable to hold extended usage info
	sub ___exthelp{
		no warnings;
		return sub {
			$extensions_help = $_[0] if $_[0];
			return $extensions_help;
		};
	}
	if(ref($progname)eq"CODE"){
		# Assuming this is a string, but it doesnt matter.
		# We allow the caller to use numbers for programs as well
		# If its just code we put it back into the param list
		unshift @_, $progname;
	}
	my $idx = 0;
	sub ___progidx {
		no warnings;
		return sub { my $tmp = $idx; $idx++; $tmp };
	};
	my $progidx = ___progidx(0);
	my @prog = ();
	for(@_){
		if(!ref($_)eq"CODE"){
			confess "Parameters to Program must be code blocks";
		}
		push @prog, $_;
	}
	my $PROGRAM = sub {
		# Last return value
		my $lr = shift;
		my $chainidx = 0;
		for(@prog){
			$lr = $_->($lr);
			print STDERR "Function should not return `undef` in program " . $progidx->() . "\n    at chain index: $chainidx\n" unless defined $lr;
			$chainidx++;
		}
		return $lr; # Return last value of function chain
	};
	return sub {
		my ($query, @params) = @_;
		if(not defined $query){
			goto HELPMSG;
		}
		elsif($query =~ /code|program/i){
			return $PROGRAM; # We return the function
		}elsif($query =~ /sub|get\s?Sub/i){
			confess "$query required 1 parameter: index of subroutine to fetch" unless defined $params[0];
			return $prog[$params[0]];
		}elsif($query =~ /name|^id$/i){
			return $progname; # We just return the program name/id
		}elsif($query =~ /chain\sLength|length|number|size/i){
			return $#prog; # We only return the size of the chain
		}elsif($query =~ /chain|sequence|seq|functions|aref|subroutines/i){
			return \@prog; # We return the original chain/sequence of values passed
		}elsif($query =~ /next\s?Index|nidx|^ni$/i){
			return $idx + 1; # We return the next internal program index
		}elsif($query =~ /^i$|idx|index/i){
			return $idx; # We just return this functions internal index
		}elsif($query =~ /source\s?file/i){
			return $sourcefile; # Return program source file + line number
		}elsif($query =~ /src/i){
			# Here we return the program source code
			# NOTE: I know this isn't lexically scoped.
			sub ___src{
				my ($file, $line) = @_;
				use autodie;
				open my $fh, "<", $file;
				my $buff = "";
				my $progstart = 0;
				while(<$fh>){
					if(m/Program\s*?\(/){
						$progstart = $.;
						$buff = $_;
						next;
					}elsif(m/Program\s*?\(/ and $. == $line){
						close $fh;
						return $_; # Source code on a single line
					}
					$buff .= $_;
					if($. == $line){
						close $fh;
						return $buff; # We found the source code
					}
				}
				confess "Error, failed to find source";
			}
			return ___src($sourcefile->[1], $sourcefile->[2]);
		}elsif($query =~ /save|store/){
			# We store the program into a file specified by the first parameter
			use autodie;
			my $fname = shift @params;
			open my $fh, ">", $fname;
			my $src = $getsrccode->();
			print $fh $src;
			close $fh;
			if(-f $fname){
				return 1; # Successfully stored program
			}else{
				return; # Signal error, file does not exist, something went wrong
			}
		}elsif($query =~ /run\s?Code|run|exe|exec|execute/i){
			return $PROGRAM->(@params); # We execute the program and return its return value
		}elsif($query =~ /^help$|usage|^info$/i){
			# TODO: Parallel/Async-Thread
			HELPMSG:
			# Here we simply display usage information for this function
			my $helpmsg = <<INFO;
	\$program\-\>(\$query,\@params);
  query :
   name | id                                = Returns name of program
   chainLength | length | number | size     = Returns the lenght of the program in number of functions
   chain | sequence | seq                   = Returns the actual sequence of subroutines
   nextIndex | nidx | ni                    = Returns the next index if the program
   idx | index                              = Returns this programs index
   runCode | run | exe | exec | execute     = Runs the program and returns the result
   help | ? | usage | info                  = Displays this help message
   nextIndex | nidx | ni                    = Returns the next program index to follow
   dualfork | daemonize | service           = Daemonize program

  params :
   This is just the array of parameters equal in function to \@_
INFO
		my $exthelp = ___exthelp()->();
		$helpmsg .= <<EXTINFO if $exthelp;
Extension information:
   $exthelp
EXTINFO
		print $helpmsg and goto NORMAL_EXIT unless $DEBUG;
		return $helpmsg;
		}elsif($query =~ /dualfork|daemonize|service/i){
			use File::Temp qw/tempfile/; # Luckily a standard module shipped with perl since v5.6.1
			my ($tmpfh,$tmpfname) = tempfile;
			my $pid = fork;
			if(defined $pid){
				if($pid != 0){
					# Parent process
					# We return, program is daemonized and we no longer need
					# to run here
					# We return the PID of the Child-Child process
					# so that we can send signals to it.
					# We sleep for 1 second to give the processes
					# time to write the grandpid into a temporary file
					sleep 1;
					local $/ = undef;
					my $grandpid = <$tmpfh>;
					close $tmpfh;
					unlink $tmpfname;
					return $grandpid;
				}else{
					# Child process
					my $daemonpid = fork;
					if(defined $daemonpid and $daemonpid != 0){
						# Child-Parent process
						# Writes the grandchild pid into the temporary file
						print $tmpfh $daemonpid;
						# We close the filehandle in this process
						close $tmpfh;
						exit 0; # We dont need this process. So we exit.
					}else{
						# Child-Child process
						# Daemonization successfull, daemonize program and exit
						# Once program completes, daemonized program terminates
						# We also close the filehandle here due to process
						# state duplication
						close $tmpfh;
						$PROGRAM->(); # Daemonized program
						exit 0;
					}
				}
			}else{
				confess "Failed to create daemon process from program. `fork` returned `undef`";
			}
		}elsif($query =~ /^(exthelp|add ?help|add ?info)$/ni){
			# Add extra help info to this specific program
			___exthelp()->(shift @params);
			return 1 if ___exthelp()->(); # Return 1, message successfully added
			goto ERROR_EXIT;
			return; # Undef is typically an error
		}elsif($query =~ /^(extend|append)/ni){
			# Append function to the end of the program
			my $sub = shift @params;
			if(!ref($sub) eq "CODE"){
				confess "Parameter to \$program->('$query', ...) must be a CODE reference";
			}
			push @prog, $sub;
			return 1; # Indicate success
		}elsif($query =~ /^prepend$/i){
			# Prepend function to the start of the program
			my $sub = shift @params;
			if(!ref($sub) eq "CODE"){
				confess "Parameter to \$program->('$query', ...) must be a CODE reference";
			}
			unshift @prog, $sub;
			return 1;
		}elsif($query =~ /insert|plugin/i){
			# Add a subroutine into the program at a given index
			my ($index, $sub) = @params;
			if(!ref($sub) eq "CODE"){
				confess "Third parameter to \$program->('$query',\$index, ...) must be a CODE reference";
			}
			splice @prog, $index, 0, $sub;
			return 1;
		}else{
			confess "Incorrect program invocation";
			return;
		}
		# If we end up here, something went wrong.
		# All of our if-blocks return
		ERROR_EXIT:
			print STDERR "ERROR[]: Terminating application to prevent further errors.\n";
			exit -1;
		NORMAL_EXIT:
			exit 0;
	};
}


#NOTE: May be removed
# Wont really work the way I thought
sub subroutine(&$@){
	my ($code, $subname, @params) = @_;
	return sub {
		my $query = shift;
		my $lambda = lambda { $code->(@_) } @params;
		# Run subroutine by default as if it were a simple sub
		return $lambda->() unless defined $query;
		# If a query is defined, we send the requested information back
		# to the caller
		if($query =~ /name|id/i){
			return $subname;
		}elsif($query =~ /execute|exe|exec|run/i){
			return $lambda->();
		}elsif($query =~ /lambda|sub|subroutine/i){
			return $lambda;
		}
	};
}

sub StateMachine($$){
	my ($vtype, $progaref) = @_;
	my $length = scalar(@$progaref);
	SWITCH:
	for($vtype){
		if(not defined $vtype or /digit/){
			return sub {
				my $STATE = 1;
				# A STATE of 0 means clean exit
				# A negative STATE integer means unclean exit
				while($STATE > 0){
					my $r = $progaref->[$STATE - 1]->('program')->($STATE);
					if($r =~ /\d+/){
						$STATE = $r;
					}else{
						$STATE++;
						if($STATE > $length - 1){
							$STATE = 0;
						}
					}
				}
				return $STATE;
			};
		}
		if(/hash/){
			return sub {
				my $STATEH = { state => 1};
				while($STATEH->{state} > 0){
					my $prevstate = $STATEH->{state};
					$STATEH = $progaref->[$STATEH->{state} - 1]->('program')->($STATEH);
					confess "Return value must be a hash reference" unless ref($STATEH) eq "HASH";
					confess "No 'state' keyword found. Terminating." unless defined $STATEH->{state};
					if($prevstate == $STATEH->{state}){
						# No next state specified, use fallthrough method
						$STATEH->{state}++;
						if($STATEH->{state} > $length){
							# Go back to state 1
							$STATEH->{state} = 1;
						}
					}
				}
				return $STATEH;
			};
		}
		if(/array/){
			return sub {
				my $STATEA = [1];
				while($STATEA->[0] > 0){
					my $prevstate = $STATEA->[0];
					$STATEA = $progaref->[$STATEA->[0] - 1]->('program')->($STATEA);
					confess "Return value must be an array reference" unless ref($STATEA) eq "ARRAY";
					# We have to assume the first index of $aref is the next state
					confess "0th index of return value must be an integer" unless $STATEA->[0] =~ /\d+/;
					if($prevstate == $STATEA->[0]){
						# No state change, use fallthrough
						$STATEA->[0]++;
						if($STATEA->[0] > $length){
							# Restart
							$STATEA->[0] = 1;
						}
					}
				}
				return $STATEA;
			};
		}else{
			confess "Invalid parameters";
		}
	}
}

sub curry($$){
	my ($f1,$f2) = @_;
	for(@_){
		if(!ref($_)eq"CODE"){
			confess "Parameters to curry must be code blocks";
		}
	}
	return sub {
		# We reverse the curry order for easier use
		return $f2->($f1->());
	};
}

sub Machine(@){
	my %statetable = @_;
	unless(exists $statetable{start}){
		confess "Machine must have the 'start' key in its state table";
	}
	return sub {
		START:
		my $STATEH = \%statetable;
		$STATEH->{state} = 'start';
		while($STATEH->{state} ne 'end' or not defined $STATEH->{state}){
			my $prevstate = $STATEH->{state};
			$STATEH = $STATEH->{$STATEH->{state}}->('program')->($STATEH);
			if(!ref($STATEH) eq "HASH" or $STATEH->{state} eq $prevstate){
				confess "This type of machine cannot continue without a state value being returned by its programs. Terminating.";
			}
			# Some extra functionality
			# Reset machine to point 0
			if($STATEH->{state} eq "_reset"){
				goto START;
			}
		}
		return $STATEH;
	};
}

sub list($$){
	my($size, $initial_val) = @_;
	return map { $initial_val } 0 .. $size-1;
}

# Example ruleset matrix
# my $matrix = {
# 	1 => {
# 		up => [2, 3],
# 		down => [3, 2],
# 		left => [3, 1],
# 		right => [3, 2]
# 	},
# 	2 => {
# 		up => [1, 2],
# 		down => [2, 3],
# 		right => [1],
# 		left => [3]
# 	},
# 	3 => {
# 		up => [1, 2],
# 		down => [2, 1],
# 		left => [2, 1],
# 		right => [3, 1]
# 	}
# };

sub RulesMatrix($@){
	my ($size, %rules) = @_;
	my @matrix = ();
	for(0 .. $rules{size}-1){
		push @matrix, [ list $rules{size}, 0 ];
	}
	return lambda {
		confess "Not yet implemented";
	};
}

# Returns true if param1 is in list param2
sub in($@){
	my ($v, @a) = @_;
	return any { $v == $_ } @a;
}


# Example linear ruleset vector
# TODO
# $vector = {
# 	1 => [[ 2, 3, 4],[1, 2, 3]],
#            ^-left | right-^
# 	2 => [[ 1, 3, 2],[3,2,1]],
# 	3 => [[ 1, 2],[3,1]],
# 	4 => [[ 3, 2],[2,3]]
# };

sub randomchoice(@){
	my $r = $_[int(rand($#_))];
	return $r;
}

sub funcall($;@){
	my $lbd = shift;
	confess "Not a function reference" unless ref($lbd) eq "CODE";
	return $lbd->(@_);
}

sub RulesLinear($@){
	my %ruleset = @_;
	my $size = (values %ruleset);
	my $resolve; # For possible recursion
	$resolve = lambda {
		my $position = shift // int(randomchoice keys %ruleset);
		my @vec = list $size, undef;
		$vec[0] = $position;
		for(1 .. $#vec){
			my $left = $ruleset{$position}->[0];
			my $right = $ruleset{$position}->[1];
			for my $candidate(@$right){
				my $cleft = $ruleset{$candidate}->[0];
				if(in($position, @$cleft)){
					$vec[$_] = $candidate;
					$position = $candidate;
					next;
				}
			}
		}
		return wantarray? @vec : pack("(C*)", @vec);
	};
	return $resolve;
}

# Example linear ruleset vector
# $vector = {
# 	1 => [ 2, 3, 4],
# 	2 => [ 1, 3, 2],
# 	3 => [ 1, 2],
# 	4 => [ 3, 2]
# };

# So far only generates rules from left to right at random
sub RulesLinearRandom($%){
	my ($size, %ruleset) = @_;
	my @vec = list $size, 0;
	my $hn = max keys %ruleset;
	my $iszero = lambda {
		my $idx = shift;
		$vec[$idx] = int rand ($hn) if $vec[$idx] == 0;
	};
	$iszero->(0);
	my $determineNext = lambda {
		my ($curidx) = @_; # Should be correct
		my $linearRule = $ruleset{$curidx};
		return $ruleset{$curidx}->[int(rand(@{$ruleset{$curidx}}))-1];
	};
	return lambda {
		for(0 .. $#vec){
			$vec[$_] = $determineNext->($_+1);
		}
		return wantarray ? @vec : pack("C*", @vec);
	};
}

*Rules = *RulesMatrix;

# NOTE: Idea for later
sub Monolith(@){
	my $table = \%{@_};
	exists $table->{machines} and
	exists $table->{programs} and
	exists $table->{triggers};
}

sub loadProgram($){
	my $fname = shift;
	use autodie;
	open my $fh, "<", $fname;
	local $/ = undef;
	my $contents = <$fh>;
	close $fh;
	# This returns the program subroutine
	# NOTE: String eval intentional here
	return eval $contents;
}

1;
__END__

=head1 NAME

Program - A dynamic and functional extension for program creation, maintenence, change/update
and further extension.

=head1 SYNOPSIS

	use Program qw/Program StateMachine lambda subroutine curry/;
	# Create a program out of subroutines
	# The first paramater, which is the
	# program name, is optional
	my $prog = Program(
		'my program',
		sub {
			my $v = 3;
			return $v;
		},
		sub {
			return shift() * 10;
		}
	);
	# Run the program
	print $prog->('exec'); # => 30
	#or
	print $prog->('program')->(); # => 30

	# Reuse a program
	my $nprog = Program(
		$prog->('program'),
		sub {
			my $retval = shift;
			return $retval * 3;
		}
	);
	print $nprog->('program')->(); # => 90

	# Get a specific subroutine out of a program
	# based on index (0-based)
	my $initial_value = $prog->('sub',0)->();
	print $initial_value; # => 3

	# Append a function to the program
	push @{$nprog->('seq')}, $nprog->('sub',1);
	print $nprog->('program')->(); # => 270
	# or
	$nprog->('extend', sub { ... });
	# or
	$nprog->('append', sub { ... });

	# Prepend a function to the program
	$nprog->('prepend', sub { ... });

	# Insert/Plug-in a function into the program at an index
	$nprog->('plugin', 1, sub { ... });
	
	# Get the program name/id
	print $prog->('id'); # => my program
	print $nprog->('id'); # => 1

	# Display built-in help/usage message
	$prog->('help');  # => <help message/usage text>
	# or
	$prog->(); # => <help message/usage text>

	# Daemonize a program
	my $pid = $nprog->('daemonize');
	# or
	my $pid = $nprog->('service');
	# or
	my $pid = $nprog->('dualfork');
	print $pid; # => <daemon PID>

	# Stop the daemon
	kill $pid;

	# Create an anonymous function with 'baked in' parameters
	my $lambda = lambda { ... } qw(param1 param2 ...);
	$lambda->($more, $parameters);

	# Curry
	my $curried = curry(sub { return 5 }, sub { $_[0] * 2});
	print $curried->(); # => 10
	my $morecurried = curry($curried, sub { $_[0] * 5});
	print $morecurried->(); # => 50


=head1 DESCRIPTION

The Program module aims to provide
a functional interface to the creation
of programs of arbitrary length and complexity.

The flexibility provided herewithin aims to simplify
the extension of any given program created with this
method. Allowing function-based programs to be
updated/changed/repaired 'on the fly' so to speak

As of version 0.01 there isn't much built-in
support for debugging purposes.

=head2 EXPORT

=over 4

=item Program

	See SYNOPSIS for example usage.

=item StateMachine

	TODO

=item RulesLinearRandom

	Returns a random sequence of numbers based on a
	random value in the ruleset

=item RulesLinear($optionalStartPosition)

	Returns a sequence of numbers based on the ruleset.
	returns a packed value in scalar context and
	an array in list context.

	In scalar context, the values can be unpacked
	into an array with 'unpack("C*", $packed);'

	The size of the array is equal to the number
	of keys in the parameter.

	This function takes an optional start position.
	If the start position is not specified, it picks
	one at random.

	CODE:
	my $rules = RulesLinear(
		0 => [[4],[1]],
		1 => [[0],[2]],
		2 => [[1],[3]],
		3 => [[2],[4]],
		4 => [[3],[0]]
	);
	my @result = $rules->();
	print @result; # => 40123 for example
	# Linear rules are made out of valid 'preceeding' integers
	# and valid 'follow-up' integers. If the rule cannot be satisfied
	# 'undef' remains in its place
	---

	The above ruleset will generate a sequence of numbers
	from 0 to 4 increasing, starting from a random
	position. So 12340, 34012, 23401, etc.

	Each key corresponds to a list of pairs.
	The list on the left represents 'allowed' integers
	on the left from the given number
	The list on the right represents 'allowed' integers
	on the right from the given number.

	So, in our example 0 can be followed up only with
	the number 1, while its preceeding number must be 4.
	The number 1 can only be followed up by the number
	2 but can only be preceeded by the number 0
	The number 2 can be followed up only by the number
	3 but can only be preceeded by the number 1

	Simmilarly, the number 2 must be preceeded by 1
	The number 3 must be preceeded by 2
	The number 0 must be preceeded by 4

	In case the rule cannot be satisfied, undef
	is placed in its place.
	For example, if the above example had the code
		0 => [[0],[1]],
		...
	Then right after 4, undef would be placed.
	Because we have said, that the number 0 must be
	preceeded by ONLY a 0, and that the only valid
	number following up 4 is 0, the ruleset
	cannot be satisifed.
	If instead we wrote
		0 => [[4,0],[1]],
		...
	Then this issue will be resolved, since
	the number 0 can now be preceeded by a 4 as well.

=item lambda({CODE}, @params)

	returns a function with baked-in @params

=item subroutine

	TODO

=item curry(\&func1, \&func2)

	Returns a function that combines \&func1 and \&func2

=item in($what, @array)

	Returns true if $what is found in @array.
	false otherwise

=item randomchoice(@array)

	Returns a random value from the given array

=back

=head1 SEE ALSO

Functional programing, State machines, prelref for 'closures'
and static variables.

Possibly perlpacktut for pack/unpack functions

Website:
https://majorendian.github.io/software/perl-Program

=head1 AUTHOR

Ernest Deak

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Ernest Deak

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

=cut
