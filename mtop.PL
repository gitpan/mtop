#!/usr/local/bin/perl

#  (DO NOT EDIT mtop, instead edit mtop.PL and run make

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

#  (DO NOT EDIT mtop, instead edit mtop.PL and run make

print OUT <<'!NO!SUBS!';
#
# $Id: mtop.PL,v 1.43 2002/03/07 03:54:11 mdprewitt Exp $
#
# mtop - Shows the MySQL commands consuming the greatest time
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

B<mtop> - Shows top mysql threads

=head1 SYNOPSIS

    mtop [--host={mysql_host}] [--dbuser={mysql_user}] 
        [--password={mysqluser_pw}] [--seconds={refresh}] [--[no]idle] 
        [--filter-user={regex}] [--filter-host={regex}] [--filter-db={regex}]
        [--filter-command={regex}] [--filter-state={regex}] [--filter-info={{regex}}]
        [--user={user}] [--manualrefresh]

    mtop --help

    mtop --version

=head1 DESCRIPTION

Shows the MySQL commands consuming the greatest time.  By default, only non-sleeping 
threads are shown, the B<--idle> option shows idle threads.  While running several 
keys will affect the operation of B<mtop>.  Hitting B<h> or B<?> will show the 
available options.

Normally, run as a console program this will allow you to see errant or badly 
optimized queries as they will stay on the screen for a while.  However, if you
are hunting for short lived queries, running in the B<manualrefresh> mode with a 
short refresh time will allow you to catch short lived queries as well.

The following keys are active while mtop is running:

    q - quit
    ? - help
    f - flush status
    k - kill processes; send a kill to a list of ids
    s - change the number of seconds to delay between updates
    m - toggle manual refresh mode on/off
    d - filter display with regular expression (user/host/db/command/state/info)
    h - display process for only one host
    u - display process for only one user
    i - toggle all/non-Sleeping process display
    o - reverse the sort order
    e - explain a process; show query optimizer info
    t - show mysqld stats (show status/mysqladmin ext)
    v - show mysqld variables (show variables/mysqladmin vars)
    z - zoom in on a process; show sql statement detail 

When viewing the I<stats> screen, the screen will refresh until a key is 
pressed at which point you will return to the main screen.  The bottom of the 
I<stats> screen is denoted with a line containing B<--->, if you do not see
that line, resize your screen until you do.

The I<variables> screen only shows the information once and returns to the main 
screen as the variables do not change after server startup.

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

=item -s {refresh}, --seconds={refresh}

The default screen refresh is 5 seconds.

=item -i, --[no]idle 

By default, processes in the B<Sleep> command state are not shown.  This option turns
on display of idle threads.

=item -u {user}, --user={user}

Show only threads owned by this user.

=item -fu {regex_pattern}, --filter-user={regex_pattern}

=item -fh {regex_pattern}, --filter-host={regex_pattern}

=item -fd {regex_pattern}, --filter-db={regex_pattern}

=item -fs {regex_pattern}, --filter-state={regex_pattern}

=item -fc {regex_pattern}, --filter-command={regex_pattern}

=item -fi {regex_pattern}, --filter-info={regex_pattern}

Filter the display based on the B<regex_pattern> provided.  The B<regex_pattern> is a perl
regular expression.  The regular expression match is done with case insensitivity.

For example, to only show B<select> statements on the B<user> table, use the following:

    --filter-info='select from user'

or, to be more forgiving for mutil-table joins and extra spaces, use:

    --filter-info='select\s+from\s+.*\buser\b.*where'

These same regular expression filters can be used with the interactive B<d> command.
Be careful to escape any special shell characters in the regex.

=item -m, --manualrefresh 

In this mode, the screen only refreshes when the user hits a key on the
keyboard.  The screen will refresh automatically until a query is seen and then wait for 
further input.  An uppercase M will appear in the top right hand corner of the screen to 
indicate that you are in this mode.

=back

=head1 SETUP

The most convenient way to setup your system to use B<mtop> is to create a database user
called B<mysqltop> which has no password.  For security purposes, this user should have 
all privileges set to B<N> except B<Process_priv> which must be set to B<Y>.

To grant these privileges, execute the following from the MySQL command prompt

    mysql> grant select on test.* to mysqltop;
    mysql> grant select on test.* to mysqltop@localhost;
    mysql> update user set process_priv='y' where user='mysqltop';
    mysql> flush privileges;

Note: GRANT only works in MySQL 3.22.11 or later, for earlier versions add the user
manually and fix the permissions as noted above.  Note 2: the GRANT to mysqltop and
mysqltop@localhost may be modified depending upon which hosts you want to grant
access from.  In general, you probably want to limit it to the hosts in your
domain.

In addition, the B<mysqltop> user must have B<Select_priv> to the B<test> database.  This 
requirement is only needed because the DBI driver requires a database to connect to even
though no database commands are issued.  Most commands this program issues are non-database
specific (SHOW FULL PROCESSLIST, SHOW VARIABLES, KILL id).  When database-specific
commands are needed, mtop will prompt for a username/password if the default one fails.

To install mtop, run the following shell commands:

    perl Makefile.PL
    make
    make install

The default {install_prefix} is /usr/local which means that mtop is installed 
in /usr/local/bin/.  To change this, run:

    perl Makefile.PL --prefix={install_prefix}
    
or modify the PREFIX line in Makefile.PL.

Requires DBD::mysql, Curses, and Net::Domain.

=head1 AUTHOR

Marc Prewitt, Chelsea Networks <mprewitt@chelsea.net>

Copyright (C) 2002 Marc Prewitt/Chelsea Networks, under the GNU GPL.
mtop comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
welcome to redistribute it under certain conditions; see the COPYING file 
for details.

=head1 BUGS

Win2K telnet.exe - If you are using the Windows 2000 telnet program, it defaults
to ansi mode which doesn't work well with curses (in my testing on Solaris 8).  
To work around this, set the terminal type to vt100.  To do this, issue the
following command from the telnet prompt before connecting to a host:

    set term vt100

Alternatively, you can manually set your TERM environment variable to vt100
after you are logged in.

=head1 TODO

Feature to allow regex filters on other display columns.  Show
current filters.

Offer sorts by other columns

For the 'More:' paging, it would be nice to support 'Less' behaviour.

Add 'show status' and 'show variables' output.

Add support for saving commandline opts in ~/.mtop

Add 'n' command and properly calculate number of lines on screen.

    $Id: mtop.PL,v 1.43 2002/03/07 03:54:11 mdprewitt Exp $

=cut

use strict;
use vars qw( $VERSION $RELEASE %PROC_COLS @PROC_COLS %EXPLAIN_COLS @EXPLAIN_COLS $WINDOW_RESIZE );

use DBI;
use DBD::mysql;
use Getopt::Long;
use Curses;
use Net::Domain qw( hostdomain );

my $DOMAIN = hostdomain();

use constant NOECHO => 1;
use constant DESC => 1;

my $opt_host = "";
my $opt_dbport = "";
my $opt_dbsocket = "";
my $opt_dbuser = "mysqltop";
my $opt_passwd = "";
my $opt_seconds = 5;
my $opt_idle = 0;
my $opt_user;
my $opt_version;
my $opt_help;
my $opt_manualrefresh;

my $opt_filterhost;
my $opt_filteruser;
my $opt_filterdb;
my $opt_filtercommand;
my $opt_filterstate;
my $opt_filterinfo;

my $PROMPT_ROW = 3;
my $SORT = DESC;

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

@EXPLAIN_COLS = ( qw( table type possible_keys key ken_len ref rows Extra ) );

%EXPLAIN_COLS = ( 
        table => 12,
        type  => 8,
        possible_keys => 20,
        key => 12,
        ken_len => 8,
        'ref' => 8,
        rows => 6,
        Extra => -1
);

my %PROCS;   # place to save proc info between refreshes

my %STATS;  # 'show status' info

my %VARS;    # 'show variables' info

# dbh's to other databases format is 
# $DB{db_name}
#
my %DB;    

GetOptions(
        'h|host:s'            => \$opt_host,
        'dbuser:s'            => \$opt_dbuser,
        'dbport:i'            => \$opt_dbport,
        'dbsocket:s'          => \$opt_dbsocket,
        'user:s'              => \$opt_user,
        'password:s'          => \$opt_passwd,
        'seconds:i'           => \$opt_seconds,
        'fu|filter-user:s'    => \$opt_filteruser,
        'fh|filter-host:s'    => \$opt_filterhost,
        'fd|filter-db:s'      => \$opt_filterdb,
        'fc|filter-command:s' => \$opt_filtercommand,
        'fs|filter-state:s'   => \$opt_filterstate,
        'fi|filter-info:s'    => \$opt_filterinfo,
        'version'             => \$opt_version,
        'help|?'              => \$opt_help,
        'manualrefresh'       => \$opt_manualrefresh,
        'idle!'               => \$opt_idle,
    ) || usage();
    
$| = 1;

show_version() if $opt_version;
usage() if $opt_help;

my $dbh;
my $dsn = "DBI:mysql:database=test";
my $dsn_opts;
$dsn_opts = ";host=$opt_host" if $opt_host;
$dsn_opts .= ";port=$opt_dbport" if $opt_dbport;
$dsn_opts .= ";mysql_socket=$opt_dbsocket" if $opt_dbsocket;


$dbh = DBI->connect("$dsn$dsn_opts", $opt_dbuser, $opt_passwd, {PrintError=>0}) || 
    die "Unable to connect to mysql [", $DBI::errstr, "]\n";

my $st_procs   = $dbh->prepare("show full processlist");
my $st_status  = $dbh->prepare("show status");
my $st_kill    = $dbh->prepare("kill ?");
my $st_flush   = $dbh->prepare("flush status");
my $st_vars    = $dbh->prepare("show variables");

my $CURSES_INIT;
my $SCREEN_WIDTH;
my $SCREEN_HEIGHT;
my $ALMOST_SLOW_COLOR;
my $SLOW_COLOR;
my $REALLY_SLOW_COLOR;

init_screen();

$WINDOW_RESIZE = 0;
$SIG{WINCH} = sub { $WINDOW_RESIZE = 1 };

my $reset = time + $opt_seconds;
refresh_vars();
refresh_screen();


while (1) {
    my $key;
    if ( $opt_manualrefresh && scalar %PROCS ) {
        $key = pause("Press any key to continue or e/z:");
    } else {
        $key = getch_nb();
    }
    my $refresh = 0;
    if ($key eq "q") {
        last;
    } elsif ($key eq "k") {
        $refresh = do_kill();
    } elsif ($key eq "s") {
        $refresh = do_seconds();
    } elsif ($key eq "m") {
        if ($opt_manualrefresh) { $opt_manualrefresh = 0 } else { $opt_manualrefresh = 1 };
        next; # skip the rest of the loop to immediately go into manual mode
    } elsif ($key eq "i") {
        if ($opt_idle) { $opt_idle = 0 } else { $opt_idle = 1 };
        $refresh = 1;
    } elsif ($key eq "d") {
        $refresh = do_filter();
    } elsif ($key eq "h") {
        $refresh = do_host();
    } elsif ($key eq "u") {
        $refresh = do_user();
    } elsif ($key eq "+") {
        $refresh = $opt_user = "";
    } elsif ($key eq "e") {
        $refresh = do_explain();
    } elsif ($key eq "t") {
        $refresh = do_stats();
    } elsif ($key eq "v") {
        $refresh = do_vars();
    } elsif ($key eq "f") {
        $refresh = do_flush();
    } elsif ($key eq "o") {
        if ($SORT) { $SORT = 0 } else { $SORT = 1 };
        $refresh = 1;
    } elsif ($key eq "z") {
        $refresh = do_zoom();
    } elsif ($key eq "?") {
        $refresh = do_help();
    } else {
        refresh_screen();
    }
    refresh_screen() if $refresh;

    sleep_or_key($opt_seconds);

    if ($WINDOW_RESIZE) {
        handle_resize();
    }
}

#
#  Show detail for a number of commands
#
sub do_zoom {
    my $line = get_string("Id(s)");

    my @ids = split(/\s+/, $line);
    my @info;
    foreach my $id (@ids) {
        push @info,  get_id_detail($id), " ";
    }
    return error("No Ids") unless @info;
    if (scalar @info) {
        more(@info);
        my $ch = pause( "Press any key to continue or 'e' to explain a statement:");
        if (lc($ch) eq 'e') {
            do_explain();
        }
    }
    return 1;
}

#
#  Show the mysqld variables
#
sub do_vars {
    refresh_vars();

    my @keys = sort keys %VARS;
    my $mid = int(scalar @keys / 2);

    my @vars;
    for (my $i=0; $i<=$mid; $i++) {
        my $val1 = $VARS{$keys[$i]};
        my $val2 = $VARS{$keys[$i+$mid]};
        $val1 = commify($val1) if $val1 =~ /^\d+$/;
        $val2 = commify($val2) if $val2 =~ /^\d+$/;
        my $spaces1 = " " x ($SCREEN_WIDTH/2 - length($val1) - length($keys[$i]) - 4);
        my $spaces2 = " " x ($SCREEN_WIDTH/2 - length($val2) - length($keys[$i+$mid]) - 4);
        my $line = "$keys[$i]: $spaces1$val1";
        $line .= "  $keys[$i+$mid]: $spaces2$val2" if $keys[$i+$mid];
        push @vars, $line;
    }
    more(@vars);
    pause();
    return 1;
}

#
#  Show the mysqld status settings
#
sub do_stats {
    my @keys = sort keys %STATS;
    my $mid = int(scalar @keys / 2);

    move(0,0);
    clrtobot();

    do {
        if ($WINDOW_RESIZE) {
            handle_resize();
        }

        my @stats;
        refresh_stats();
        my $i;
        for ($i=0; $i<=$mid; $i++) {
            my $val1 = $STATS{$keys[$i]};
            my $val2 = $STATS{$keys[$i+$mid]};
            $val1 = commify($val1) if $val1 =~ /^\d+$/;
            $val2 = commify($val2) if $val2 =~ /^\d+$/;
            my $spaces1 = " " x ($SCREEN_WIDTH/2 - length($val1) - length($keys[$i]) - 4);
            my $spaces2 = " " x ($SCREEN_WIDTH/2 - length($val2) - length($keys[$i+$mid]) - 4);
            my $line = "$keys[$i]: $spaces1$val1";
            $line .= "  $keys[$i+$mid]: $spaces2$val2" if $keys[$i+$mid];
            addstr($i, 0, $line) if $line;
        }
        addstr($i, 0, "---");
        message("Press any key to return") 
    } while !sleep_or_key($opt_seconds) || getch_nb() == -1;
    return 1;
}

#
#  Show the help screen (clears the screen).
#
sub do_help {
    refresh_vars();
    my $keybuffer = friendly_bytes($VARS{key_buffer_size});
    my $sortbuffer = friendly_bytes($VARS{sort_buffer});
    my $help = qq{mtop ver $VERSION/$RELEASE, Copyright (c) 2002, Marc Prewitt/Chelsea Networks

A top users display for mysql

These single-character commands are available:

q - quit
? - help; show this text
f - flush status
k - kill processes; send a kill to a list of ids
s - change the number of seconds to delay between updates
m - toggle manual refresh mode on/off
d - filter display with regular expression (user/host/db/command/state/info)
h - display process for only one host
u - display process for only one user
i - toggle all/non-Sleeping process display
o - reverse the sort order
e - explain a process; show query optimizer info
t - show mysqld stats (show status/mysqladmin ext)
v - show mysqld variables (show variables/mysqladmin vars)
z - zoom in on a process, show sql statement detail 

Stats Explanation (See SHOW STATUS docs for full details):

Cache Hit:     Key_read / Key_read_requests. If small, consider increasing 
               key_buffer_size (current=$keybuffer)
Opened tables: If large, consider increasing table_cache 
               (current=$VARS{table_cache})
RRN:           Handler_read_rnd_next High if you are doing a lot of table scans.
TLW:           Table_locks_waited If high, consider optimising queries or 
               splitting db.
SFJ:           Select_full_join Number of joins without keys (Should be 0). 
SMP:           Sort_merge_passes If high, consider increasing sort_buffer 
               (current=$sortbuffer).
    };
    more($help);
    pause();
    return 1;
}

#
#  Change the current users displayed
#
sub do_user {
    $opt_user = get_string("user");
    message("");
    return 1;
}

#
#  Change the current host displayed
#
sub do_host {
    $opt_filterhost = get_string("host");
    message("");
    return 1;
}

#
#  Change the current set of filters used for display
#
sub do_filter {
    my $filteron = lc(get_string("filter type (u/h/d/c/s/i/?): "));
    my $prompt = "enter perl regex for filter or return to clear: ";

    if ($filteron eq 'u') {
        $opt_filteruser = get_string($prompt);
    } elsif ($filteron eq 'h') { 
        $opt_filterhost = get_string($prompt);
    } elsif ($filteron eq 'd') {
        $opt_filterdb = get_string($prompt);
    } elsif ($filteron eq 'c') {
        $opt_filtercommand = get_string($prompt);
    } elsif ($filteron eq 's') {
        $opt_filterstate = get_string($prompt);
    } elsif ($filteron eq 'i') {
        $opt_filterinfo = get_string($prompt);
    } elsif ($filteron eq '?') {
        more("Curent display filters: 

    user    =~ m/$opt_filteruser/i
    host    =~ m/$opt_filterhost/i
    db      =~ m/$opt_filterdb/i
    command =~ m/$opt_filtercommand/i
    state   =~ m/$opt_filterstate/i
    info    =~ m/$opt_filterinfo/i
        ");
        pause();
    } else {
        return error("Invalid filter option");
    }
    return 1;
}

#
#  Change the refresh interval
#
sub do_seconds {
    my $secstr = get_string("seconds");
    if (!$secstr || $secstr =~ /\D/) {
        return error("Illegal value!");
    } else {
        $opt_seconds = $secstr;
    }
    return 1;
}

#
#  Do an explain on the queries in question
#
sub do_explain {
    my $line = get_string("explain");
    my @ids = split(/\s+/, $line);
    my @info;
    message("Waiting for locks...");
    foreach my $id (@ids) {
        push @info,  get_id_explain($id), " ";
    }
    if (scalar @info) {
        more(@info);
    } else {
        return error("No Ids");
    }
    pause();
    return 1;
}

#
#  Kill processes, ask the user for ids and kill each one of them
#
sub do_kill {
    my $line = get_string("kill");
    my @pids = split(/\s+/, $line);
    return error("No Ids") unless @pids;
    addstr($PROMPT_ROW, 0, "killing " . join(" ", @pids));
    foreach (@pids) {
        $st_kill->execute($_) if $_;
    }
    message("");
    return 1;
}

#
#  Flush the status to reset the global variables
#
sub do_flush {
    $st_flush->execute() || error("Unable to execute flush status " . $dbh->errstr());
    refresh_vars();
}

# 
#  Does a 'show variables' and updates %VARS with the results
#
sub refresh_vars {
    $st_vars->execute() || die "Unable to execute show variables" . $dbh->errstr() . "\n";
    while (my $row = $st_vars->fetchrow_hashref()) {
        $VARS{$row->{Variable_name}} = $row->{Value};
    }
}

# 
#  Does a 'show status' and updates %STATS with the results
#
sub refresh_stats {
    $st_status->execute() || die "Unable to execute show status" . $dbh->errstr() . "\n";
    while (my $row = $st_status->fetchrow_hashref()) {
        $STATS{$row->{Variable_name}} = $row->{Value};
    }
}

#
#  Display the header at the top of the page.
#
sub header() {
    refresh_stats();

    my $load_avg = "$opt_host ";
    # Only show load average and memory if we're monitoring the local machine
    if (!$opt_host) {
        $load_avg .= `uptime`;
        chomp($load_avg);
        $load_avg =~ s/.*load/load/;

    }
    my $mysql_memory = get_mysql_memory();
    $mysql_memory = "  MEM: " . friendly_bytes($mysql_memory) if $mysql_memory;

    my $time  = $STATS{Uptime}; $time =~ s/,//g;
    my $days  = int( $time / 86400);
    my $hours = int(($time % 86400) / (60 * 60));
    my $min   = int(($time % 86400) / 60 % 60);
    $min   = "0$min"   if $min < 10;
    $hours = " $hours" if $hours < 10;
    
    my $krr = $STATS{Key_read_requests} || 1;
    my $kr  = $STATS{Key_reads};
    my $chit = 100 - ($kr/$krr) * 100;
    $chit = sprintf("%2.2f",$chit);

    my $questions   = friendly_number($STATS{Questions}, 1);
    my $slow        = friendly_number($STATS{Slow_queries}, 1);
    my $open_tables = friendly_number($STATS{Opened_tables}, 1);
    my $rrn         = friendly_number($STATS{Handler_read_rnd_next}, 1);
    my $tlw         = friendly_number($STATS{Table_locks_waited}, 1);
    my $sfj         = friendly_number($STATS{Select_full_join}, 1);
    my $smp         = friendly_number($STATS{Sort_merge_passes}, 1);

    addstr(0,0, $load_avg . " mysqld $VARS{version} up $days day(s), $hours:$min hrs");
    addstr(1,0, "$STATS{Threads_connected} threads: $STATS{Threads_running} running, $STATS{Threads_cached} cached. Queries/slow: $questions/$slow Cache Hit: $chit%");

    addstr(2,0, "Opened tables: $open_tables  RRN: $rrn  TLW: $tlw  SFJ: $sfj  SMP: $smp$mysql_memory");
    if ($opt_manualrefresh) {
        standout();
        addstr(0,$SCREEN_WIDTH-1, "M");
        standend();
    } else {
        addstr(0,$SCREEN_WIDTH-1, " ");
    }
}

#
#  Put a new header on the screen.
#  Grab new process list, save it in %PROCS by Id and display.
#
sub refresh_screen {
    move(0, 0);
    clrtobot();
    header();
    $st_procs->execute() || die "Unable to execute show procs" . $dbh->errstr() . "\n";
    my @rows;
    while (my $row = $st_procs->fetchrow_hashref()) {
        if ( filter_ok($row) ) {
            push @rows, $row;
        }
    }
    my $rownum = 4;
    my $c = 0;
    foreach my $col (@PROC_COLS) {
        addstr($rownum, $c, uc($col));
        $c += $PROC_COLS{$col} +1;
    }
    $rownum++;
    %PROCS = ();
    foreach my $row (sort sort_procs @rows) {
        $PROCS{$row->{Id}} = $row;
        $c = 0;
        foreach my $col (@PROC_COLS) {
            my $width = $PROC_COLS{$col};
            if ( $width == -1 ) {
                $width = $SCREEN_WIDTH - $c;
            }

            my $data = $row->{$col};
            # Remove nl and multi spaces so that data doesn't move off the 
            # line it's supposed to be on.
            $data =~ s/\n//g;
            $data =~ s/\s+/ /g;
            $data =~ s/\.$DOMAIN//o if $col eq "Host";
            $data = substr($data, 0, $width);  # limit the data to the width of the column

            my $query_color = query_color($row);
            attron($query_color) if $query_color;
            addstr($rownum, $c, $data) if $data;
            attroff($query_color) if $query_color;
            $c += $width +1;
        }
        $rownum++;
    }
    addstr($rownum, 0, "---");
    move(0,0);
    refresh();
}

#
#  Returns an array consisting of detail for a command
#
sub get_id_detail {
    my $id = shift;
    
    if ($id =~ /\D/) {
        return "Id: $id is an invalid id number.";
    } elsif (!exists $PROCS{$id}) {
        return "Id: $id not found";
    }
    my $proc = $PROCS{$id};
    return (
            "Id: $id User: $proc->{User} Host: $proc->{Host} Db: $proc->{db} Time: $proc->{Time}",
            "Command: $proc->{Command} State: $proc->{State}", " ",
            split_sql($proc->{Info}), ""
    );
}

#
#  Returns an array consisting of explain info for a query
#
sub get_id_explain {
    my $id = shift;
    
    if ($id =~ /\D/) {
        return "Id: $id is an invalid id number.";
    } elsif (!exists $PROCS{$id}) {
        return "Id: $id not found";
    }

    my $db = $PROCS{$id}->{db};
    my $dbh;
    if (!($dbh = $DB{$db})) { 
        my $connect = "DBI:mysql:$db";

        # Try to connect as the default user
        $dbh = DBI->connect("$connect$dsn_opts", $opt_dbuser, $opt_passwd, {PrintError=>0});
        if (!$dbh) {
            # Otherwise, prompt for an alternate username/password
            my $alt_dbuser = get_string("Unable to connect to $db as $opt_dbuser, enter user for $db: ");
            my $alt_passwd = get_string("Password: ", NOECHO);
            $dbh = DBI->connect("$connect$dsn_opts", $alt_dbuser, $alt_passwd, {PrintError=>0}) ||
                return "Unable to connect to $connect$dsn_opts as $opt_dbuser or $alt_dbuser";
        }
        $DB{$db} = $dbh;
    }
    my $st_explain = $dbh->prepare("explain $PROCS{$id}->{Info}");
    $st_explain->execute();

    my @rows = (get_id_detail($id), " ");
    push @rows, sprintf("%-12.12s|%-8.8s|%-20.20s|%-12.12s|%8.8s|%-8.8s|%6.6s|", @EXPLAIN_COLS);
    while (my $row = $st_explain->fetchrow_arrayref()) {
        if ($row) {
            my $line = sprintf("%-12.12s|%-8.8s|%-20.20s|%-12.12s|%8.8s|%-8.8s|%6.6s", @$row);
            my $leftover = $SCREEN_WIDTH - length($line) - 1;
            $line .= "|" . substr($row->[-1], 0, $leftover);
            push @rows, $line;
        }
    }
    return @rows;
}

############################################################################
#  
#  Utility routines
#

sub commify {
    local $_  = shift;
    return 0 unless defined $_;
    1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
    return $_;
}

#
#  Prompt the user for input on the PROMPT_ROW and return what they typed in
#
sub get_string {
    my $prompt = shift;
    my $noecho = shift;
    my $string = "";

    move($SCREEN_HEIGHT-1, 0);
    clrtoeol();
    standout();
    addstr($SCREEN_HEIGHT-1, 0, $prompt);
    standend();
    move($SCREEN_HEIGHT-1, length($prompt) + 1);
    if ($noecho) { noecho() } else { echo() }
    nodelay(0);  # blocking-reads
    getnstr($string, 1024);  # prevent possible buffer overflow with getn
    move($SCREEN_HEIGHT-1, 0);
    clrtoeol();
    chomp($string);
    return $string;
}

#
#  Display info on the screen on 'page' at a time.
#  Strings are split on '\n'.
#
sub more {
    move(0,0);
    clrtobot();
    my $row = 0;
    foreach (@_) {
        foreach (split(/\n/)) {
            addstr($row++, 0, $_);
            if ($row == $SCREEN_HEIGHT-1) {
                return if lc(pause("More: ")) eq "q";
                move(0,0);
                clrtobot();
                $row = 0;
            }
        }
    }
}

#
#  Displays the first argument or 'press any key' at the bottom of the 
#  screen and waits for the user to press a key.  The message is cleared
#  after a key is pressed.
#
#  Returns the character that was pressed.
#
sub pause {
    my $msg = shift || "Press any key to continue:";
    standout();
    addstr($SCREEN_HEIGHT-1, 0, $msg);
    standend();
    refresh();
    nodelay(0);             # so getch() is blocking
    my $ch = getch();
    move($SCREEN_HEIGHT-1, 0);
    clrtoeol();
    refresh();
    return $ch;
}

#
# Print a highlighted message at the bottom of the screen
#
sub message {
    my $msg = shift;
    standout();
    move($SCREEN_HEIGHT-1, 0);
    clrtoeol();
    addstr($SCREEN_HEIGHT-1, 0, $msg);
    standend();
    move(0,0);
    refresh();
    return 1;
}

#
#  call &message() and return 0
#
sub error {
    message(@_);
    return 0;
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
#  Returns a key pressed in non-blocking mode
#  Doesn't restore previous blocking mode, so
#  reset as needed
#
sub getch_nb {
    noecho();               
    nodelay(1);             # so getch() is non-blocking
    return getch();
}

#
#  Split a sql command into multiple lines nicely formatted.
#  An array of lines is returned.
#
sub split_sql {
    my $sql = shift;
    $sql =~ s/,\s*/, /g;
    $sql =~ s/\s+,/,/g;
    $sql =~ s/\(\s+/\(/g;
    $sql =~ s/\s+\)/\)/g;
    $sql =~ s/\s+/ /g;
    $sql =~ s/\s+from\s+/\n  FROM /i;
    $sql =~ s/\s+values\s+/\n  VALUES /i;
    $sql =~ s/\s+into\s+/\n  INTO /i;
    $sql =~ s/\s+where\s+/\n  WHERE /i;
    $sql =~ s/\s+having\s+/\n  HAVING /i;
    $sql =~ s/\s+limit\s+/\n  LIMIT /i;
    $sql =~ s/\s+procedure\s+/\n  PROCEDURE /i;
    $sql =~ s/\s+order\s+by\s+/\n  ORDER BY /i;
    $sql =~ s/\s+group\s+by\s+/\n  GROUP BY /i;
    my @result;
    foreach my $line (split(/\n/, $sql)) {
        while ($line) {
            my $linewidth = length($line);
            if ($linewidth > $SCREEN_WIDTH) {
                $linewidth = rindex($line, " ", $SCREEN_WIDTH);
                if ($linewidth == -1) { $linewidth = $SCREEN_WIDTH; }
            }
            push @result, substr($line, 0, $linewidth);
            $line = substr($line, $linewidth);
            $line = "    $line" if $line;
        }
    }
    return @result;
}

#
#  Convert a number into KB, MB, GB, TB
#
sub friendly_bytes {
    return friendly_number(@_) . "B";
}

#
#  Convert a number into K, M, G, T
#
#  $i: number to convert
#  $d: number of decimal places to show if $i is < 1024
#
sub friendly_number {
    my $i = shift;
    my $d = shift;

    my ($size, $ret_i);
    if ($i < 1024) {
        $ret_i = $i;
    } elsif ( ($i = $i/1024) < 1024 ) {
        $ret_i = $i;
        $size = "K";
    } elsif ( ($i = $i/1024) < 1024 ) {
        $ret_i = $i;
        $size = "M";
    } elsif ( ($i = $i/1024) < 1024 ) {
        $ret_i = $i;
        $size = "G";
    } else {
        $ret_i = $i = $i/1024;
        $size = "T";
    }
    if ($d && int($ret_i) != $ret_i) {
        $ret_i = sprintf("%.${d}f", $ret_i);
    } else {
        $ret_i = int($ret_i);
    }
    return "$ret_i$size";
}

#  
#  Return 1 if the specified row passes the current set of 
#  dipslay filters.
#
sub filter_ok {
    my $row = shift;
    return 1 if
        (!$opt_user          or $row->{User}    eq $opt_user) &&
        (!$opt_filteruser    or $row->{User}    =~ /$opt_filteruser/i) &&
        (!$opt_filterhost    or $row->{Host}    =~ /$opt_filterhost/i) &&
        (!$opt_filterdb      or $row->{Db}      =~ /$opt_filterdb/i) &&
        (!$opt_filtercommand or $row->{Command} =~ /$opt_filtercommand/i) &&
        (!$opt_filterstate   or $row->{State}   =~ /$opt_filterstate/i) &&
        (!$opt_filterinfo    or $row->{Info}    =~ /$opt_filterinfo/i) &&
        ($opt_idle           or $row->{Command} ne "Sleep" );
    return 0;
}

#
#  Return the attribute that should be used to display a query based
#  on how long the query is taking.  Returns 0 if attribute shouldn't 
#  be changed.
#
sub query_color {
    my $sth = shift;
    if ($sth->{Command} eq "Query") {
        my $time = $sth->{Time};
        if ($time > $VARS{long_query_time} * 2) {
            return $REALLY_SLOW_COLOR;
        } elsif ($time > $VARS{long_query_time}) {
            return $SLOW_COLOR;
        } elsif ($time > $VARS{long_query_time} / 2) {
            return $ALMOST_SLOW_COLOR;
        }
    }
    return 0;
}

#
#  Initializes curses and set global screen constants
#  see curs_attr(3CURSES) for details
#
sub init_screen {
    $CURSES_INIT = 1 if initscr();      # start screen
    start_color();
    cbreak(); 
    getmaxyx($SCREEN_HEIGHT, $SCREEN_WIDTH);

    if (has_colors()) {
        init_pair(1, COLOR_RED, COLOR_BLACK);
        init_pair(2, COLOR_YELLOW, COLOR_BLACK);
        init_pair(3, COLOR_MAGENTA, COLOR_BLACK);
        $ALMOST_SLOW_COLOR = COLOR_PAIR(3);
        $SLOW_COLOR = COLOR_PAIR(2);
        $REALLY_SLOW_COLOR = COLOR_PAIR(1);
    } else {
        $ALMOST_SLOW_COLOR = A_DIM;
        $SLOW_COLOR = A_BOLD;
        $REALLY_SLOW_COLOR = A_REVERSE;
    }
}
#
#  Reinitialize curses system.
#
sub handle_resize {
    endwin() if $CURSES_INIT;
    init_screen();
    refresh();
    $WINDOW_RESIZE = 0;
}

sub sort_procs {
    if ($SORT == DESC) {
        return $b->{Time} <=> $a->{Time};
    } else {
        return $a->{Time} <=> $b->{Time};
    }
}

sub show_version {
    endwin() if $CURSES_INIT;
    print "\n", version(), "\n";
    exit;
}

#
#  Returns the pid of the running mysql server or
#  0 if the pid cannot be determined.
#
sub get_mysql_pid {
    if ( -r $VARS{pid_file} ) {
        open(PID, $VARS{pid_file}) || return undef;
        chomp(my $pid = <PID>);
        return $pid;
    } else {
        return 0;
    }
}

#
#  Returns the amount of memory used by the server.
#  Currently only works if the server is the local machine.
#
my $MYSQL_PID;
sub get_mysql_memory {
    if (!$opt_host) {
        $MYSQL_PID = get_mysql_pid() unless defined $MYSQL_PID;

        if ( $MYSQL_PID && -f "/proc/$MYSQL_PID/as" ) {
            return ((stat(_))[7]) 
        }
    }
    return undef;
}

sub version {
    return "mtop ver $VERSION/$RELEASE";
}

sub usage {
    endwin() if $CURSES_INIT;
    print "\n", version(), qq{

Copyright (C) 2002 Marc Prewitt/Chelsea Networks <mprewitt\@chelsea.net>
mtop comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
welcome to redistribute it under certain conditions; see the COPYING file 
for details.

Usage: mtop [OPTIONS]

  --version                  Show version number and exit
  --help                     Show this screen and exit
  --host={mysql_host}        Connect to the MySQL server on {mysql_host}
  --dbuser={mysql_user}      Connect to the MySQL server as {mysql_user}
  --password={mysqluser_pw}  Use {mysqluser_pw} when connecting
  --seconds={refresh}        Refresh the screen each {refresh} seconds
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

See 'man mtop' or 'perldoc mtop' for more information.

};
    exit();
}

sub cleanup_win {
    if ($CURSES_INIT) {
        move(0,0);
        clrtobot();
        refresh();
        endwin();
    }
}

sub die {
    CORE::die(@_);
}

END {
    cleanup_win();
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
