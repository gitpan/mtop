#!/usr/local/bin/perl

#  (DO NOT EDIT fwd_skytel, instead edit fwd_skytel.PL and run make

use Config;
use File::Basename qw(&basename &dirname);
use strict;

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

!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

#  (DO NOT EDIT mtop, instead edit mtop.PL and run make

print OUT <<'!NO!SUBS!';
#
# $Id: mtop.PL,v 1.21 2001/12/14 20:39:52 mprewitt Exp $
#
# (C) 2001 Chelsea Networks/Marc Prewitt <mprewitt@chelsea.net>, under 
# the GNU GPL.
# 
# mtop is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# mtop is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You may have received a copy of the GNU General Public License
# along with mtop see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
=head1 NAME 

B<mtop> - Shows top mysql threads

=head1 DESCRIPTION

    mtop [--host {mysql_host}] [--dbuser {mysql_user}] [--password {mysqluser_pw}] [--seconds {refresh}] [--[no]idle] [--user {user}]

Shows the commands consuming the greatest time.  By default, only non-sleeping 
threads are shown, the B<--idle> option shows idle threads.  While running several 
keys will affect the operation of B<mtop>.  Hitting B<h> or B<?> will show the 
available options.

The following keys are active while mtop is running:

    q       - quit
    h or ?  - help
    k       - kill processes; send a kill to a list of ids
    s       - change the number of seconds to delay between updates
    u       - display process for only one user (+ selects all users)
    i       - toggle all/non-Sleeping process display
    o       - reverse the sort order
    e       - explain a process; show query optimizer info
    z       - zoom in on a process; show sql statement detail 

=head1 OPTIONS

=over 4

B<--host {mysql_host}>  By default, the mysqld on localhost is monitored.  Specify an alternate host
with this option.

B<--dbuser {mysql_user}>  By default, the user 'mysqltop' is used to connect to the database.  Specify an alternate user with this option.

B<--password {mysqluser_pw}>  By default, there is no password associated with the mysqltop
user, specify a password with this option.

B<--seconds {refresh}>  The default screen refresh is 5 seconds.

B<--[no]idle> By default, processes in the B<Sleep> command state are not shown.  This option turns
on display of idle threads.

B<--user {user}>  Show only threads owned by this user.

=back

Requires DBD::mysql, Curses, and Net::Domain.

=head1 SETUP

The most convenient way to setup your system to use B<mtop> is to create a database user
called B<mysqltop> which has no password.  For security purposes, this user should have 
all privileges set to B<N> except B<Process_priv> which must be set to B<Y>.

In addition, the B<mysqltop> user must have B<Select_priv> to the B<test> database.  This 
requirement is only needed becuase the DBI driver requires a database to connect to even
though no database commands are issued.  The only commands this program issues are non-database
specific (SHOW FULL PROCESSLIST, SHOW VARIABLES, KILL id).

=head1 AUTHOR

Marc Prewitt, Chelsea Networks <mprewitt@chelsea.net>

=head1 TODO

Add flush status

Offer sorts by other columns

For the 'More:' paging, it would be nice to support 'Less' behaviour.

Add 'show status' and 'show variables' output.

Add support for saving commandline opts in ~/.mtop

Add 'n' command and properly calculate number of lines on screen.

=cut

use strict;
use vars qw( $VERSION %PROC_COLS @PROC_COLS %EXPLAIN_COLS @EXPLAIN_COLS $WINDOW_RESIZE );

$VERSION = (qw$Revision: 1.21 $)[1];

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
        "host:s"     => \$opt_host,
        "dbuser:s"   => \$opt_dbuser,
        "dbport:i"   => \$opt_dbport,
        "dbsocket:s" => \$opt_dbsocket,
        "user:s"     => \$opt_user,
        "password:s" => \$opt_passwd,
        "seconds:i"  => \$opt_seconds,
        "idle!"      => \$opt_idle,
    ) || die "Usage: mtop [--host {mysql_host}] [--dbuser {mysql_user}] [--password {mysqluser_pw}] [--seconds {refresh}] [--[no]idle] [--user {user}]\n";

$| = 1;

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
my $st_vars    = $dbh->prepare("show variables");
# This will have to be on a different dbh...
my $st_explain = $dbh->prepare("explain ?");

my $CURSES_INIT;
my $SCREEN_WIDTH;
my $SCREEN_HEIGHT;
my $ALMOST_SLOW_COLOR;
my $SLOW_COLOR;
my $REALLY_SLOW_COLOR;

init_screen();

$WINDOW_RESIZE = 0;
$SIG{WINCH} = sub { $WINDOW_RESIZE = 1 };

#  Try to lower our priority (which, who, pri)
setpriority(0,0,20);

my $reset = time + $opt_seconds;
refresh_vars();
while (1) {
    noecho();               
    nodelay(1);             # so getch() is non-blocking
    if ((my $key = getch()) ne ERR) {        
        my $status = 0;
        if ($key eq "q") {
            last;
        } elsif ($key eq "k") {
            $status = do_kill();
        } elsif ($key eq "s") {
            $status = do_seconds();
        } elsif ($key eq "i") {
            if ($opt_idle) { $opt_idle = 0 } else { $opt_idle = 1 };
            $status = 1;
        } elsif ($key eq "u") {
            $status = do_user();
        } elsif ($key eq "+") {
            $status = $opt_user = "";
        } elsif ($key eq "e") {
            $status = do_explain();
        } elsif ($key eq "o") {
            if ($SORT) { $SORT = 0 } else { $SORT = 1 };
            $status = 1;
        } elsif ($key eq "z") {
            $status = do_zoom();
        } elsif ($key eq "?" || $key eq "h") {
            $status = do_help();
        } else {
            refresh_screen();
        }
        refresh_screen() if $status;
    }
    my ($in, $out) = ('', '');
    vec($in,fileno(STDIN),1) = 1;           # look for key on stdin 
    select($out = $in,undef,undef,$opt_seconds);# wait up to this long
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
    my $help = qq{mtop version $VERSION, Copyright (c) 2001, Chelsea Networks

A top users display for mysql

These single-character commands are available:

q       - quit
h or ?  - help; show this text
k       - kill processes; send a kill to a list of ids
s       - change the number of seconds to delay between updates
u       - display process for only one user (+ selects all users)
i       - toggle all/non-Sleeping process display
o       - reverse the sort order
e       - explain a process; show query optimizer info
z       - zoom in on a process, show sql statement detail 

Stats Explanation (See SHOW STATUS docs for full details):

Cache Hit:     Key_read / Key_read_requests. If small, consider increasing 
               key_cache (current=$keybuffer)
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
#  Does a 'show variables' and updates %VARS with the results
#
sub refresh_vars {
    $st_vars->execute() || die "Unable to execute show variables" . $dbh->errmsg();
    while (my $row = $st_vars->fetchrow_hashref()) {
        $VARS{$row->{Variable_name}} = $row->{Value};
    }
}

# 
#  Does a 'show status' and updates %STATS with the results
#
sub refresh_stats {
    $st_status->execute() || die "Unable to execute show status" . $dbh->errmsg();
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
        $load_avg .=~ s/.*load/load/;
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
}

#
#  Put a new header on the screen.
#  Grab new process list, save it in %PROCS by Id and display.
#
sub refresh_screen {
    move(0, 0);
    clrtobot();
    header();
    $st_procs->execute() || die "Unable to execute show procs" . $dbh->errmsg();
    my @rows;
    while (my $row = $st_procs->fetchrow_hashref()) {
        if ( !$opt_user || $opt_user eq $row->{User} ) {
            if ($opt_idle || $row->{Command} ne "Sleep" ) {
                push @rows, $row;
            }
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
            if ( $col eq "Host" ) {
                $data =~ s/\.$DOMAIN//o;
            }
            $data = substr($data, 0, $width);
            my $query_color = query_color($row);
            attron($query_color) if $query_color;
            addstr($rownum, $c, $data) if $data;
            attroff($query_color) if $query_color;
            $c += $width +1;
        }
        $rownum++;
    }
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
            my $alt_dbuser = get_string("Unable to connect to $db as $opt_dbuser, enter user for $db ");
            my $alt_passwd = get_string("Password ", NOECHO);
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
                pause("More: ");
                move(0,0);
                clrtobot();
                $row = 0;
            }
        }
    }
}

#
#  Displays a 'press any key' message at the bottom of the 
#  screen and waits for the user to press a key.
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
    return $ch;
}

#
# print a highlighted message at the bottom of the screen
#
sub message {
    my $msg = shift;
    standout();
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
END {
    endwin() if $CURSES_INIT;
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
