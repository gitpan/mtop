#!/usr/local/bin/perl

use Config;
use File::Basename qw(&basename &dirname);
use Getopt::Long;
use strict;
use vars ( qw( $opt_v $opt_r ) );

GetOptions(
    "version=s"=>\$opt_v,
    "release=s"=>\$opt_r,
);

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
my $file;
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
        if ($Config{'osname'} eq 'VMS' or
            $Config{'osname'} eq 'OS2');  # "case-forgiving"

open OUT,">$file" or die "Can't create $file: $!";
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'}

\$VERSION = "$opt_v";
\$RELEASE = "$opt_r";

!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

#  (DO NOT EDIT mkill, instead edit mkill.PL and run make

print OUT <<'!NO!SUBS!';
#
# $Id: mkill.PL,v 1.2 2003/06/20 14:36:43 mdprewitt Exp $
#
# mkill - Kill longs running queries
# Copyright (C) 2002 Marc Prewitt/Chelsea Networks <mprewitt@chelsea.net>
# 
# This program is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
# 
#

=head1 NAME 

B<mkill> - Kills slow queries

=head1 SYNOPSIS

    mkill [--host={mysql_host}] [--dbuser={mysql_user}] 
        [--password={mysqluser_pw}] 
        [--filter-user={regex}] [--filter-host={regex}] [--filter-db={regex}]
        [--filter-command={regex}] [--filter-state={regex}] [--filter-info={{regex}}]
        [--user={user}] [--slow={seconds}] 
        [--daemonize]

    mkill --help

    mkill --version

=head1 DESCRIPTION

This is an alpha version of this program.  Please let me know what you think and what
additional features would be nice.  Future version will most likely perform the same
but have different output.  One idea i've been thinking about is letting you specify
filters which short perl snippets instead of just regexes.  

This program kills long running queries based on several criteria including query time,
host, user, database, state, and query content.

The following keys are active while mkill is running:

    q - quit

=head1 OPTIONS

All options can be abbreviated by their shortest unique abbreviation.

=over 4

=item -?, --help  

Show the help screen and exit.

=item -v, --version  

Show the version number and exit.

=item -h {mysql_host}, --host={mysql_host}  

By default, the mysqld on localhost is monitored.  Specify an alternate host
with this option.

=item -dbu {mysql_user}, --dbuser={mysql_user}

By default, the user 'mysqltop' is used to connect to the database.  Specify an alternate user with this option.

=item -p {mysqluser_pw}, --password={mysqluser_pw}

By default, there is no password associated with the mysqltop
user, specify a password with this option.

=item -sl {seconds}, --slow={seconds}

The number of seconds before a slow query is killed.  The default is
180 seconds.

=back

=head1 FILTER OPTIONS

=over 4

=item -u {user}, --user={user}

Kill only threads owned by this user.

=item -fu {regex_pattern}, --filter-user={regex_pattern}

=item -fh {regex_pattern}, --filter-host={regex_pattern}

=item -fd {regex_pattern}, --filter-db={regex_pattern}

=item -fs {regex_pattern}, --filter-state={regex_pattern}

=item -fc {regex_pattern}, --filter-command={regex_pattern}

=item -fi {regex_pattern}, --filter-info={regex_pattern}

Filter the queries based on the B<regex_pattern> provided.  The B<regex_pattern> is a perl
regular expression.  The regular expression match is done with case insensitivity.

For example, to only kill B<select> statements on the B<user> table, use the following:

    --filter-info='select from user'

or, to be more forgiving for mutil-table joins and extra spaces, use:

    --filter-info='select\s+from\s+.*\buser\b.*where'

Be careful to escape any special shell characters in the regex.

=back

All options can be stored in initialization files.  Command line options override
options stored in the initialization file(s).  The following files are checked for
arguments: current direcotry .mkillc, home directory .mkillc, /usr/local/etc/mkillc, 
/etc/mkillc.  Options in the former files override options in the later files.

The format of the initialization file is one option per line.  Options are specified just
as they would be on the command line.  They can be abbreviated and use the one or two hyphen
syntax.  Comments and blank lines are ignored.  The following is an exmple .mkillc file 
which kills any 'select' statements from 'user1' which last more than 120 seconds.

    #  Only kill 'user1' 'select' queries > 120 seconds
    -fu user1
    -filter-info='select'
    --slow=1   # refresh every one seconds

=head1 SETUP

The most convenient way to setup your system to use B<mkill> is to create a database user
called B<mysqlkill> which has no password.  For security purposes, this user should have 
all privileges set to B<N> except B<Process_priv> which must be set to B<Y>.

To grant these privileges, execute the following from the MySQL command prompt

    mysql> grant select on test.* to mysqlkill;
    mysql> grant select on test.* to mysqlkill@localhost;
    mysql> update user set process_priv='y' where user='mysqlkill';
    mysql> flush privileges;

Note: GRANT only works in MySQL 3.22.11 or later, for earlier versions add the user
manually and fix the permissions as noted above.  Note 2: the GRANT to mysqlkill and
mysqlkill@localhost may be modified depending upon which hosts you want to grant
access from.  In general, you probably want to limit it to the hosts in your
domain.

In addition, the B<mysqlkill> user must have B<Select_priv> to the B<test> database.  This 
requirement is only needed because the DBI driver requires a database to connect to even
though no database commands are issued.  Most commands this program issues are non-database
specific (SHOW FULL PROCESSLIST, SHOW VARIABLES, KILL id).  When database-specific
commands are needed, mkill will prompt for a username/password if the default one fails.

To install mkill, run the following shell commands:

    perl Makefile.PL
    make
    make install

The default {install_prefix} is /usr/local which means that mkill is installed 
in /usr/local/bin/.  To change this, run:

    perl Makefile.PL --prefix={install_prefix}
    
or modify the PREFIX line in Makefile.PL.

Requires the following perl modules:

    Module        Available At
    ------------  --------------------------------------------------------
    DBI           Distributed as Bundle::DBI: http://www.cpan.org/authors/id/TIMB
    DBD::mysql    http://www.cpan.org/authors/id/JWIED
    Getopt::Long  (Distributed with Perl 5)
    Net::Domain   Part of libnet: http://www.cpan.org/authors/id/GBARR/

=head1 AUTHOR

Marc Prewitt, Chelsea Networks <mprewitt@chelsea.net>

Copyright (C) 2003 Marc Prewitt/Chelsea Networks, under the GNU GPL.
mkill comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
welcome to redistribute it under certain conditions; see the COPYING file 
for details.

=head1 KNOWN BUGS

    $Id: mkill.PL,v 1.2 2003/06/20 14:36:43 mdprewitt Exp $

The get char routines used to quit the program currently require the user
to hit the RETURN key on the keyboard after entry.  This will soon be
fixed.

=cut

use strict;

use vars qw( $VERSION $RELEASE %PROC_COLS @PROC_COLS %EXPLAIN_COLS @EXPLAIN_COLS $WINDOW_RESIZE );

use DBI;
use DBD::mysql;
use Getopt::Long;
use Net::Domain qw( hostdomain );

my $DOMAIN = hostdomain();

use constant NOECHO => 1;
use constant DESC => 1;

my $opt_host = "";
my $opt_dbport = "";
my $opt_dbsocket = "";
my $opt_dbuser = "mysqltop";
my $opt_passwd = "";
my $opt_user;
my $opt_version;
my $opt_help;

my $opt_slow = 180;

my $opt_filterhost;
my $opt_filteruser;
my $opt_filterdb;
my $opt_filtercommand;
my $opt_filterstate;
my $opt_filterinfo;

my $DEBUG;

@PROC_COLS = ( qw( Id User Host db Time Command State Info ) );  # order of labels

#  width of columns, -1 means rest of the screen
%PROC_COLS = (  
        Id=>8,
        User=>8,
        Host=>16,
        db=>12,
        Time=>6,
        Command=>7,
        State=>12,
        Info=>-1 );

my %PROCS;       # place to save proc info between refreshes

my $HEADER;
foreach my $col (@PROC_COLS) {
    $HEADER .= uc($col) . " " x ($PROC_COLS{$col} - length($col) +1);
}
$HEADER .= "\n";

# dbh's to other databases format is 
# $DB{db_name}
#
my %DB;    

GetFileToArgv(".mkillrc")                if -e ".mkillrc";
GetFileToArgv("$ENV{HOME}/.mkillrc")     if $ENV{HOME} && -e "$ENV{HOME}/.mkillrc";
GetFileToArgv("/usr/local/etc/mkillrc")  if -e "/usr/local/etc/mkillrc";
GetFileToArgv("/etc/mkillrc")            if -e "/etc/mkillrc";

GetOptions(
        'debug:i'             => \$DEBUG,
        'h|host:s'            => \$opt_host,
        'dbuser:s'            => \$opt_dbuser,
        'dbport:i'            => \$opt_dbport,
        'dbsocket:s'          => \$opt_dbsocket,
        'user:s'              => \$opt_user,
        'password:s'          => \$opt_passwd,
        'slow:i'              => \$opt_slow,
        'fu|filter-user:s'    => \$opt_filteruser,
        'fh|filter-host:s'    => \$opt_filterhost,
        'fd|filter-db:s'      => \$opt_filterdb,
        'fc|filter-command:s' => \$opt_filtercommand,
        'fs|filter-state:s'   => \$opt_filterstate,
        'fi|filter-info:s'    => \$opt_filterinfo,
        'version'             => \$opt_version,
        'help|?'              => \$opt_help,
    ) || usage();
    
$DEBUG = 1 if defined $DEBUG;

$| = 1;

show_version() if $opt_version;
usage() if $opt_help;

my $dbh;
my $dsn = "DBI:mysql:database=test";
my %dsn_opts;
$dsn_opts{host}         = "$opt_host"     if $opt_host;
$dsn_opts{port}         = "$opt_dbport"   if $opt_dbport;
$dsn_opts{mysql_socket} = "$opt_dbsocket" if $opt_dbsocket;


#$dbh = DBI->connect($dsn . get_dsnoptstr(%dsn_opts), $opt_dbuser, $opt_passwd, {PrintError=>0}) || 
$dbh = get_dbh('test', %dsn_opts) ||
    die "Unable to connect to mysql [", $DBI::errstr, "]\n";

my $st_procs   = $dbh->prepare("show full processlist");
my $st_kill    = $dbh->prepare("kill ?");

my $key;
while (1) {
    if ($key eq "q") {
        last;
    }
    my $longest_query = refresh_screen();

    my $sleep = $opt_slow - $longest_query;
    $sleep = $opt_slow if $sleep < 1;
    print "Sleeping $sleep seconds (q to exit)...\n";
    if (sleep_or_key($sleep)) {
        $key = getc();
    }
}

#
#  Kill processes
#
sub kill_thread {
    foreach (@_) {
        $st_kill->execute($_);
    }
    return 1;
}

#
#  Grab new process list, save it in %PROCS by Id and display.
#  Return the time of the longest running query.
#
sub refresh_screen {
    my $max = 0;
    my $header;
    $st_procs->execute() || die "Unable to execute show procs [" . $dbh->errstr() . "]\n";
    my @rows;
    while (my $row = $st_procs->fetchrow_hashref()) {
        if ( filter_ok($row) ) {
            push @rows, $row;
        }
    }
    my $rownum = 4;
    %PROCS = ();
    foreach my $row (sort sort_procs @rows) {
        print date_time(), " Watching:\n", $HEADER unless $header++;
        $PROCS{$row->{Id}} = $row;
        my $line;
        my $kill;
        foreach my $col (@PROC_COLS) {
            my $data = $row->{$col};
            $max = $data if $col eq "Time" && $data > $max;
            # Remove nl and multi spaces so we get one line in the log
            $data =~ s/\n//g;
            $data =~ s/\.$DOMAIN//o if $col eq "Host";
            $data =~ s/\s+/ /g;
            $data =~ s/^\s+//;
            # limit the data to the width of the column
            $data = substr($data, 0, $PROC_COLS{$col}) unless $col eq "Info";  
            if ($col eq "Time" and $data >= $opt_slow) {
                $kill = kill_thread($row->{Id});
            }

            $line .= $data . " " x ($PROC_COLS{$col} - length($data) +1);
        }
        if ($kill) {
            print STDERR date_time(), " Killed: \n$line";
        } else {
            print "$line\n";
        }
    }
    return $max;
}

############################################################################
#  
#  Utility routines
#

sub date_time {
    return scalar localtime();
}

# 
#  Sleep for the number of seconds provided or
#  until a key is pressed (on stdin)
#
#  Returns 0 if timed out, 1 if key pressed
#
#  From the 'Perl Cookbook', Chapter 15.12, Managing the Screen
#  and 7.13, Reading from Many File Handles Without Blocking
#
sub sleep_or_key {
    my $secs = shift;

    my ($in, $out) = ('', '');
    vec($in,fileno(STDIN),1) = 1;         # look for key on stdin 
    my $nfound = select($out = $in,undef,undef,$secs); # wait up to this long
    if ($nfound && vec($out, fileno(STDIN), 1)) {
        return 1;
    } else {
        return 0;
    }
}


#  
#  Return 1 if the specified row passes the current set of 
#  dipslay filters.
#
sub filter_ok {
    my $row = shift;
    return 1 if
        (!$opt_user          or $row->{User}    eq $opt_user) &&
        (!$opt_filteruser    or $row->{User}    =~ m{$opt_filteruser}i) &&
        (!$opt_filterhost    or $row->{Host}    =~ m{$opt_filterhost}i) &&
        (!$opt_filterdb      or $row->{Db}      =~ m{$opt_filterdb}i) &&
        (!$opt_filtercommand or $row->{Command} =~ m{$opt_filtercommand}i) &&
        (!$opt_filterstate   or $row->{State}   =~ m{$opt_filterstate}i) &&
        (!$opt_filterinfo    or $row->{Info}    =~ m{$opt_filterinfo}i);
    return 0;
}

sub sort_procs {
    return $a->{Time} <=> $b->{Time};
}

sub show_version {
    print "\n", version(), "\n";
    exit;
}

#
#  Returns a dbh for a mysql db.  Prompts the user
#  for a username/password if unable to connect as the default
#  user.
#
#  Additional params will be appended to the dsn.
# 
#  dbh's are cached so that the next time the same one is needed
#  a reconnection is not needed.
#
sub get_dbh {
    my $db = shift;
    my %params = @_;

    my $dsn_opts = get_dsnoptstr(%params);

    my $dbh;
    my $dsn = "DBI:mysql:$db$dsn_opts";
    if (!($dbh = $DB{$dsn})) { 

        # Try to connect as the default user
        print STDERR "Getting dbh for $dsn with user=$opt_dbuser\n" if $DEBUG;
        $dbh = DBI->connect($dsn, $opt_dbuser, $opt_passwd, {PrintError=>0});
        if (!$dbh) {
            # Otherwise, prompt for an alternate username/password
            my $dbname = $dsn;
            $dbname =~ s/.*://;
            my $alt_dbuser = get_string("Unable to connect to $dbname as $opt_dbuser, enter another user user: ");
            my $alt_passwd = get_string("Password: ", NOECHO);
            $dbh = DBI->connect($dsn, $alt_dbuser, $alt_passwd, {PrintError=>0}) || 
                pause("Unable to connect to $dsn as $opt_dbuser or $alt_dbuser") && return 0;
            print STDERR "Getting dbh for $dsn with user=$alt_dbuser\n" if $DEBUG;
        }
        $DB{$dsn} = $dbh;
    }
    return $dbh;
}

#
#  Return a list of dsn options specified by key/value pairs in %params.
#  Return format is:
#     ;key1=val1;key2=val2;...
#
sub get_dsnoptstr {
    my %params = @_;
    my $ret;
    foreach my $key (keys %params) {
        $ret .= ";$key=$params{$key}";
    }
    return $ret;
}

sub version {
    return "mkill ver $VERSION/$RELEASE";
}

sub GetFileToArgv {
    my $file = shift;
    open(FL, $file) || return error("Unable to open '$file' [$!]");
    while (<FL>) {
        chomp();
        # stript comments and leading blanks
        s/#.*//;
        s/^\s+//;

        next if /^\s*$/;  # ignore blank lines
        unshift @ARGV, split(/\s+/);
    }
}

#
#  If we're in the debugger, don't do this!
#

BEGIN {
    unless ( defined $DB::VERSION ) {
        sub in_eval {
            my $i = 0;
            while (my $sub = (caller($i++))[3]) {
                return 1 if $sub eq "(eval)";
            }
            return;
        }

        my $Die = sub {
            if (in_eval()) {
                #
                #  We are in an eval, so wake up and die right.
                #
                CORE::die @_;
            } else {
                print STDERR @_;
                print STDERR "Stack Trace: \n" if caller(2);
                print STDERR _getStackTrace();
            }
        };

        my $current;
        if ( $current = $SIG{__DIE__} and ref($current) eq "CODE") {
            $SIG{__DIE__} = sub { &$Die(@_); &$current(@_); }
        } else {
            $SIG{__DIE__} = sub { &$Die(@_); CORE::die "\n"; }
        }
    }
}

sub _getStackTrace {
    my $calling_sub = "main";
    my $trace;
    my $i = 2;
    while ( my @level = caller($i++) ) {
        my $line = "    at $calling_sub($level[1]:$level[2])";
        if ($level[5]) {
            $line .= " in array context";
        }
        $trace = "$line\n$trace";
        $calling_sub = $level[3];
    }
    return $trace;
}

sub usage {
    print "\n", version(), qq{

Copyright (C) 2002 Marc Prewitt/Chelsea Networks <mprewitt\@chelsea.net>
mkill comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
welcome to redistribute it under certain conditions; see the COPYING file 
for details.

Usage: mkill [OPTIONS]

  --version                  Show version number and exit
  --help                     Show this screen and exit
  --host={mysql_host}        Connect to the MySQL server on {mysql_host}
  --dbuser={mysql_user}      Connect to the MySQL server as {mysql_user}
  --password={mysqluser_pw}  Use {mysqluser_pw} when connecting
  --[no]idle                 Display/don't display idle threads
  --filter-user={regex}      Filter display based on user regular expression
  --filter-host={regex}      Filter display based on host regular expression
  --filter-db={regex}        Filter display based on db regular expression
  --filter-command={regex}   Filter display based on command regular expression
  --filter-state={regex}     Filter display based on state regular expression
  --filter-info={regex}      Filter display based on info regular expression
  --user={user}              Display threads for only {user}
  --manualrefresh            Wait for user input between refreshes

All options can be truncated to their shortest unique abbreviation.

See 'man mkill' or 'perldoc mkill' for more information.

};
    exit();
}


=begin showsatus

show status;

+--------------------------+------------+
| Variable_name            | Value      |
+--------------------------+------------+
| Aborted_clients          | 494        |
| Aborted_connects         | 0          |
| Bytes_received           | 1875816718 |
| Bytes_sent               | 1474745403 |
| Connections              | 3620       |
| Created_tmp_disk_tables  | 1          |
| Created_tmp_tables       | 147386     |
| Created_tmp_files        | 0          |
| Delayed_insert_threads   | 0          |
| Delayed_writes           | 0          |
| Delayed_errors           | 0          |
| Flush_commands           | 1          |
| Handler_delete           | 1133857    |
| Handler_read_first       | 34264      |
| Handler_read_key         | 39609950   |
| Handler_read_next        | 45171610   |
| Handler_read_prev        | 669        |
| Handler_read_rnd         | 98270      |
| Handler_read_rnd_next    | 34320339   |
| Handler_update           | 1317202    |
| Handler_write            | 3900317    |
| Key_blocks_used          | 62108      |
| Key_read_requests        | 1588523835 |
| Key_reads                | 16475545   |
| Key_write_requests       | 24619937   |
| Key_writes               | 451486     |
| Max_used_connections     | 39         |
| Not_flushed_key_blocks   | 32985      |
| Not_flushed_delayed_rows | 0          |
| Open_tables              | 224        |
| Open_files               | 449        |
| Open_streams             | 0          |
| Opened_tables            | 7081       |
| Questions                | 5894332    |
| Select_full_join         | 0          |
| Select_full_range_join   | 4          |
| Select_range             | 250520     |
| Select_range_check       | 0          |
| Select_scan              | 17094      |
| Slave_running            | ON         |
| Slave_open_temp_tables   | 0          |
| Slow_launch_threads      | 0          |
| Slow_queries             | 773        |
| Sort_merge_passes        | 0          |
| Sort_range               | 27         |
| Sort_rows                | 189581     |
| Sort_scan                | 407        |
| Table_locks_immediate    | 6006913    |
| Table_locks_waited       | 4          |
| Threads_cached           | 0          |
| Threads_created          | 3617       |
| Threads_connected        | 19         |
| Threads_running          | 1          |
| Uptime                   | 599379     |
+--------------------------+------------+

show variables;

+---------------------------------+-------------------------------------------------------------+
| Variable_name                   | Value                                                       |
+---------------------------------+-------------------------------------------------------------+
| back_log                        | 50                                                          |
| basedir                         | /opt/mysql/3.23.46/                                         |
| bdb_cache_size                  | 8388600                                                     |
| bdb_log_buffer_size             | 131072                                                      |
| bdb_home                        | /export/DB/mysqldb/                                         |
| bdb_max_lock                    | 10000                                                       |
| bdb_logdir                      |                                                             |
| bdb_shared_data                 | OFF                                                         |
| bdb_tmpdir                      | /tmp/                                                       |
| bdb_version                     | Sleepycat Software: Berkeley DB 3.2.9a: (November 28, 2001) |
| binlog_cache_size               | 32768                                                       |
| character_set                   | latin1                                                      |
| character_sets                  | latin1 cp1251                                               |
| concurrent_insert               | ON                                                          |
| connect_timeout                 | 5                                                           |
| datadir                         | /export/DB/mysqldb/                                         |
| delay_key_write                 | ON                                                          |
| delayed_insert_limit            | 100                                                         |
| delayed_insert_timeout          | 300                                                         |
| delayed_queue_size              | 1000                                                        |
| flush                           | OFF                                                         |
| flush_time                      | 0                                                           |
| have_bdb                        | YES                                                         |
| have_gemini                     | NO                                                          |
| have_innodb                     | NO                                                          |
| have_isam                       | YES                                                         |
| have_raid                       | NO                                                          |
| have_openssl                    | NO                                                          |
| have_symlink                    | YES                                                         |
| init_file                       |                                                             |
| interactive_timeout             | 28800                                                       |
| join_buffer_size                | 131072                                                      |
| key_buffer_size                 | 67104768                                                    |
| language                        | /opt/mysql/3.23.46/share/mysql/english/                     |
| large_files_support             | ON                                                          |
| locked_in_memory                | OFF                                                         |
| log                             | OFF                                                         |
| log_update                      | OFF                                                         |
| log_bin                         | OFF                                                         |
| log_slave_updates               | OFF                                                         |
| log_long_queries                | ON                                                          |
| long_query_time                 | 1                                                           |
| low_priority_updates            | ON                                                          |
| lower_case_table_names          | 0                                                           |
| max_allowed_packet              | 1047552                                                     |
| max_binlog_cache_size           | 4294967295                                                  |
| max_binlog_size                 | 1073741824                                                  |
| max_connections                 | 100                                                         |
| max_connect_errors              | 10                                                          |
| max_delayed_threads             | 20                                                          |
| max_heap_table_size             | 16777216                                                    |
| max_join_size                   | 4294967295                                                  |
| max_sort_length                 | 1024                                                        |
| max_user_connections            | 0                                                           |
| max_tmp_tables                  | 32                                                          |
| max_write_lock_count            | 4294967295                                                  |
| myisam_max_extra_sort_file_size | 256                                                         |
| myisam_max_sort_file_size       | 2047                                                        |
| myisam_recover_options          | 0                                                           |
| myisam_sort_buffer_size         | 8388608                                                     |
| net_buffer_length               | 16384                                                       |
| net_read_timeout                | 30                                                          |
| net_retry_count                 | 10                                                          |
| net_write_timeout               | 60                                                          |
| open_files_limit                | 0                                                           |
| pid_file                        | /export/DB/mysqldb/mysqld.pid                               |
| port                            | 3306                                                        |
| protocol_version                | 10                                                          |
| record_buffer                   | 16773120                                                    |
| record_rnd_buffer               | 16773120                                                    |
| query_buffer_size               | 0                                                           |
| safe_show_database              | OFF                                                         |
| server_id                       | 20                                                          |
| slave_net_timeout               | 3600                                                        |
| skip_locking                    | ON                                                          |
| skip_networking                 | OFF                                                         |
| skip_show_database              | OFF                                                         |
| slow_launch_time                | 2                                                           |
| socket                          | /var/tmp/mysql.sock                                         |
| sort_buffer                     | 16777208                                                    |
| sql_mode                        | 0                                                           |
| table_cache                     | 256                                                         |
| table_type                      | MYISAM                                                      |
| thread_cache_size               | 0                                                           |
| thread_concurrency              | 10                                                          |
| thread_stack                    | 65536                                                       |
| transaction_isolation           | READ-COMMITTED                                              |
| timezone                        | EST                                                         |
| tmp_table_size                  | 8388608                                                     |
| tmpdir                          | /tmp/                                                       |
| version                         | 3.23.46-log                                                 |
| wait_timeout                    | 28800                                                       |
+---------------------------------+-------------------------------------------------------------+

=end

!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
