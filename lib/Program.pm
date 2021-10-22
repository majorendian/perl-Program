package Program;

use 5.032001;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Program ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	curry Program genCmdSub lambda subroutine
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} },
	qw(Program genCmdSub lambda subroutine)
 );

our @EXPORT = qw(
);

our $DEBUG = 0;
our $VERSION = '0.01';

use strict;
use warnings FATAL => qw(all);
use Carp qw(cluck confess);
use Test::More;

my $cmdline = join " ", @_;

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


sub Program(@){
	my $progname = shift;
	my $extensions_help = ""; # Variable to hold extended usage info
	sub ___exthelp{
		no warnings;
		return sub { $extensions_help };
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
		}elsif($query =~ /run\s?Code|run|exe|exec|execute/i){
			return $PROGRAM->(@params); # We execute the program and return its return value
		}elsif($query =~ /^help$|usage|info/i){
			# TODO: Fork/Daemonize/Dual-Fork/Parallel/Async-Thread
			HELPMSG:
			# Here we simply display usage information for this function
			my $helpmsg = <<INFO;
	\$program\-\>([query],[params]);
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

Extension information:
  $extensions_help

INFO
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
		}elsif($query =~ /exthelp|add\s?help|add\sinfo/i){
			$extensions_help = shift @params;
			return 1 if $extensions_help; # Return 1, message successfully added
			return undef; # Undef is typically an error
		}else{
			confess "Incorrect program invokation";
			return undef;
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

sub lambda(&@){
	my ($code, @params) = @_;
	return sub {
		$code->(@params);
	};
}

sub subroutine(&$@){
	my ($code, $subname, @params) = @_;
	return sub {
		my $query = shift;
		my $lambda = lambda { $code->(@_) } @params;
		return $lambda->() unless defined $query;
		if($query =~ /name|id/i){
			return $subname;
		}elsif($query =~ /execute|exe|exec|e|run/i){
			return $lambda->();
		}elsif($query =~ /lambda|sub|subroutine/i){
			return $lambda;
		}
	};
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

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Program - A dynamic and functional extension for program creation, maintenence, change/update
and further extension.

=head1 SYNOPSIS

  use Program;
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
	print $prog->('exec'); # => 30
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
	
	# Get the program name/id
	print $prog->('id'); # => my program

	# Display built-in help/usage message
	$prog->('help');
	# or
	$prog->();
	# => <help message/usage text>


=head1 DESCRIPTION

The Program module aims to provide
a functional interface to the creation
of programs of arbitrary length and complexity.

The flexibility provided herewithin aims to simplify
the extension of any given program created with this
method. Allowing function-based programs to be
updated/changed/repaired 'on the fly'

As of version 0.01 there isn't much built-in
support for debugging purposes.

=head2 EXPORT

	Program( sub {}, sub {}, ... );

=head1 SEE ALSO

Functional Programing
State Machines
perlref for 'closures'

majorendian.github.io/software/perl-Program

=head1 AUTHOR

Ernest Deak, E<lt>tino@E<gt>

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
