use 5.032001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Program',
    VERSION_FROM      => 'lib/Program.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/Program.pm', # retrieve abstract from module
    AUTHOR            => 'Ernest Deak <tino@>',
    #LICENSE           => 'gpl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
