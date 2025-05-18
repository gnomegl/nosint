use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Nosint',
    AUTHOR             => q{gnomegl <gnome@groomla.ke>},
    VERSION_FROM       => 'lib/Nosint/CLI.pm',
    ABSTRACT_FROM      => 'lib/Nosint/CLI.pm',
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => '5.010',
    EXE_FILES          => ['bin/nosint'],
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        'JSON'            => '0',
        'LWP::UserAgent'  => '0',
        'HTTP::Request'   => '0',
        'Getopt::Long'    => '0',
        'Term::ANSIColor' => '0',
        'Time::HiRes'     => '0',
        'Exporter'        => '0',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/gnomegl/nosint.git',
                web  => 'https://github.com/gnomegl/nosint',
            },
            bugtracker => {
                web => 'https://github.com/gnomegl/nosint/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Nosint-*' },
);
