#
# $Id: Makefile.PL,v 1.5 2002/01/06 18:27:24 mprewitt Exp $
#  
#  mtop Makefile
#
#  Run:
#  
#    perl Makefile.PL 
#    make
#    make install
# 
#  To change the install prefix, pass a --prefix option to 'perl Makefile.PL' as in:
#  
#    perl Makefile.PL --prefix=/usr/local/
#
# --------------------------------------------------------------------------
#
# mtop - Shows the MySQL commands consuming the greatest time
# Copyright (C) 2002 Marc Prewitt/Chelsea Networks <mprewitt@chelsea.net>
# 
# This file is part of mtop
#
# mtop is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
# 
# mtop is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
use strict;
use ExtUtils::MakeMaker;
use Getopt::Long;

my $opt_prefix;

GetOptions(
    "prefix:s"=>\$opt_prefix,
);

my ( $y, $m, $d ) = (localtime(time))[5, 4, 3];
$y += 1900;
$m++;

$m = "0$m" if $m < 9;
$d = "0$d" if $d < 9;

my $release = "$y$m$d";
my $version = "0.2.1";

my %opts =  (
    NAME          => 'mtop',
    DISTNAME      => 'mtop',
    VERSION       => $version,
    dist          => { COMPRESS=>'gzip -9f', SUFFIX => 'gz',
                     ZIP=>'/usr/bin/zip',ZIPFLAGS=>'-rl'},
    INST_SCRIPT   => './blib/bin',
    PL_FILES      => { 'mtop.PL'=> 'mtop' },
    EXE_FILES     => [ 'mtop' ],
    PREREQ_PM     => { 'Curses' => 0,
                     'Getopt::Long' => 0,
                     'Net::Domain' => 0,
                     'DBI' => 0,
                     'DBD::mysql' => 0 }
);

# Uncomment the next line to customize the install location
# or run:
#
#  perl Makefile.PL --prefix=/opt/mtop/
#
$opts{PREFIX} = "/usr/local/";

$opts{PREFIX} = $opt_prefix if $opt_prefix;

WriteMakefile( %opts );

sub MY::processPL {
    my $self = shift;
    chomp(my $text = $self->MM::processPL());
    my @lines = split(/\n/, $text);
    foreach (@lines) {
        $_ .= " -v $version -r $release" if /\$\(PERL\)/;
    }
    return join("\n", @lines);
}
