#  See lib/ExtUtils/MakeMaker.pm for details of how to influence
#  the contents of the Makefile that is written.
#
# $Id: Makefile.PL,v 1.1 2001/12/14 20:37:53 mprewitt Exp $
#
use ExtUtils::MakeMaker;
use strict;

my $version = "0.1.1";

WriteMakefile(
    NAME        => 'mtop',
    DISTNAME    => 'mtop',
    VERSION     => $version,
    dist        => { COMPRESS=>'gzip -9f', SUFFIX => 'gz',
                     ZIP=>'/usr/bin/zip',ZIPFLAGS=>'-rl'},
    INST_SCRIPT => './blib/bin',
    PL_FILES    => { 'mtop.PL'=> 'mtop' },
    EXE_FILES   => [ 'mtop' ],
    PREREQ_PM   => { 'Curses' => 0,
                     'Getopt::Long' => 0,
                     'Net::Domain' => 0,
                     'DBI' => 0,
                     'DBD::mysql' => 0 }
);
