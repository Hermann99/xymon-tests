#! /usr/bin/perl -w
use strict;
use DBI;

#----------------------------------------------------------------------------------------
my $bb_column = 'mysql-slave';

my $slave     = '<fqdn of server>';
my $slaveport = '3306';
my $slaveuser = 'username';
my $slavepw   = 'password';

my $message = '';
my $errmsg  = '';
my $warn    = 900;
my $crit    = 3600;

my %colors  = (
                green => 0,
                yellow => 1,
                red => 2,
        );
my $color   = 'green';

use constant ERRTXTBEGIN => q{<span style=\"color:white;background-color:red\">};
use constant ERRTXTEND => q{</span>};
use constant WARNTXTBEGIN => q{<span style=\"color:black;background-color:yellow\">};
use constant WARNTXTEND => q{</span>};
use constant CLRTXTBEGIN => q{<span style=\"color:white;background-color:green\">};
use constant CLRTXTEND => q{</span>};
use constant HITXTBEGIN => q{<span style=\"color:yellow\">};
use constant HITXTEND => q{</span>};

#----------------------------------------------------------------------------------------
sub setcolor {
        my ($current, $new ) = @_;
        return ($colors{$new} > $colors{$current}) ? $new : $current;
}

#----------------------------------------------------------------------------------------
my $dbh = DBI->connect("DBI:mysql:host=$slave",$slaveuser,$slavepw,{RaiseError=>1,PrintError=>0}) 
          || die "Cannot connect to slave $slave";

my $sth = $dbh->prepare('show slave status');
$sth->execute;
my $rv = $sth->fetchrow_hashref();

my $master_host = $rv->{'Master_Host'};
my $master_user = $rv->{'Master_User'};
#print "$master_host = $rv->{'Master_Host'}\n";
my $slave_io_running = $rv->{'Slave_IO_Running'};
my $slave_io_state = $rv->{'Slave_IO_State'};
my $seconds_behind_master = $rv->{'Seconds_Behind_Master'} || 0;
my $slave_sql = $rv->{'Slave_SQL_Running'};
my $last_error = $rv->{'Last_Error'};

$sth->finish;
$dbh->disconnect;

#if ($@) {
#        $color = setcolor($color,'red');
#        $message .= "<td>Database error - $@<br/></td>";
#}

#----------------------------------------------------------------------------------------
$message = "<br/><b><u>Slave Status</u></b>";
#$message .= "\n<table border=1 style='width:100%'>\n";
$message .= "<table class=content border=1 cellpadding=5 cellspacing=0 width=100%'>\n";

$message .= "<tr><td width=170>Master Host</td><td width=250>$master_host</td><td width=300></td></tr>\n";
$message .= "<tr><td>Master User</td><td>$master_user</td><td></td></tr>\n";
$message .= "<tr><td>Slave</td><td>$slave</td><td></td></tr>\n";
        
if ($slave_io_running eq 'No') {
   $color = setcolor($color,'red');
   $errmsg = ERRTXTBEGIN.'Slave not Running'.ERRTXTEND;
   $message .= "<tr><td>IO Running</td><td>$slave_io_running</td><td>$errmsg</td></tr>\n";
}elsif ($slave_io_running eq 'Connecting') {
   $color = setcolor($color,'red');
   $errmsg = ERRTXTBEGIN.'Cannot connect to master'.ERRTXTEND;
   $message .= "<tr><td>IO Running</td><td>$slave_io_running</td><td>$errmsg</td></tr>\n";
}else{
   $message .= "<tr><td>IO Running</td><td>$slave_io_running</td><td></td></tr>\n";
}

if ($slave_sql eq 'No') {
   $color = setcolor($color,'red');
   $errmsg = ERRTXTBEGIN.'Slave SQL not Running'.ERRTXTEND;
   $message .= "<tr><td>SQL Running</td><td>$slave_sql</td><td>$errmsg</td></tr>\n";
}else{
   $message .= "<tr><td>SQL Running</td><td>$slave_sql</td><td></td></tr>\n";
}

if ($seconds_behind_master > $crit) {
   $color = setcolor($color,'red');
   $errmsg = ERRTXTBEGIN."Slave lagging by more than $crit seconds".ERRTXTEND;
   $message .= "<tr><td>Seconds behind Master</td><td>$seconds_behind_master</td><td>$errmsg</td></tr>\n";
}
elsif ($seconds_behind_master > $warn) {
   $color = setcolor($color,'yellow');
   $errmsg = WARNTXTBEGIN."Slave lagging by more than $warn seconds".WARNTXTEND;
   $message .= "<tr><td>Seconds behind Master</td><td>$seconds_behind_master</td><td>$errmsg</td></tr>\n";
}else{
   $message .= "<tr><td>Seconds behind Master</td><td>$seconds_behind_master</td><td>Slave is in sync</td></tr>\n";
}
$message .= "<tr><td>Last Error</td><td>$last_error</td><td></td></tr>\n";

$message .= "</table>";

#----------------------------------------------------------------------------------------
my $date = localtime();
system("$ENV{BB} $ENV{BBDISP} \"status $ENV{MACHINE}.$bb_column $color $date\n</pre>$message<pre>\"");
#print"$date $message\n" if $color ne 'green';
#exit 0;
#print "$color \n$message\n";
