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
# $Id: mtop.PL,v 1.38 2002/02/03 05:10:24 mdprewitt Exp $
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
    z - zoom in on a process; show sql statement detail 

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

    $Id: mtop.PL,v 1.38 2002/02/03 05:10:24 mdprewitt Exp $

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
    noecho();               
    nodelay(1);             # so getch() is non-blocking

    my $key;
    if ( $opt_manualrefresh && scalar %PROCS ) {
        $key = pause("Press any key to continue or e/z:");
    } else {
        $key = getch();
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

    my ($in, $out) = ('', '');
    vec($in,fileno(STDIN),1) = 1;                # look for key on stdin 
    select($out = $in,undef,undef,$opt_seconds); # wait up to this long
    if ($WINDOW_RESIZE) {
        handle_resize();
        $WINDOW_RESIZE = 0;
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
        $STATS{$row->{Variable_name}} = commify($row->{Value});
    }
}

#
#  Display the header at the top of the page.
#
sub header() {
    refresh_stats();

    my $load_avg = "$opt_host ";
    # Only show load average if we're monitoring the local machine
    if (!$opt_host) {
        $load_avg .= `uptime`;
        chomp($load_avg);
        $load_avg =~ s/.*load/load/;
    }

    my $time  = $STATS{Uptime}; $time =~ s/,//g;
    my $days  = int( $time / 86400);
    my $hours = int(($time % 86400) / (60 * 60));
    my $min   = int(($time % 86400) / 60 % 60);
    $min   = "0$min"   if $min < 10;
    $hours = " $hours" if $hours < 10;
    
    my $krr = $STATS{Key_read_requests} || 1;    $krr =~ s/,//g;
    my $kr  = $STATS{Key_reads};                 $kr  =~ s/,//g;
    my $chit = 100 - ($kr/$krr) * 100;
    $chit = sprintf("%2.2f",$chit);

    addstr(0,0, $load_avg . " mysqld $VARS{version} up $days day(s), $hours:$min hrs");
    addstr(1,0, "$STATS{Threads_connected} threads: $STATS{Threads_running} running, $STATS{Threads_cached} cached. Queries/slow: $STATS{Questions}/$STATS{Slow_queries} Cache Hit: $chit%");

    addstr(2,0, "Opened tables: $STATS{Opened_tables}  RRN: $STATS{Handler_read_rnd_next}  TLW: $STATS{Table_locks_waited}  SFJ: $STATS{Select_full_join}  SMP: $STATS{Sort_merge_passes}");
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
}

#
#  call &message() and return 0
#
sub error {
    message(@_);
    return 0;
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
    my $i = shift;

    return "${i}B" if $i < 1024;

    $i = int($i/1024);
    return "${i}KB" if $i < 1024;

    $i = int($i/1024);
    return "${i}MB" if $i < 1024;

    $i = int($i/1024);
    return "${i}GB" if $i < 1024;

    $i = int($i/1024);
    return "${i}TB";
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
=end

!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
