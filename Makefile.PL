use 5.032001;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Program',
    VERSION_FROM      => 'lib/Program.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
        q/Carp/ => 0,
        q/Data::Dumper/ => 0,
        q/Test::More/   => 0,
        q/List::Util/   => 0,
        q/macro/        => 0.06,
    },
    ABSTRACT_FROM     => 'lib/Program.pm', # retrieve abstract from module
    AUTHOR            => 'Ernest Deak <gordon.zar@gmail.com>',
    LICENSE           => 'gpl',
);
