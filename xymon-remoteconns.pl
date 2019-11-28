#!/usr/bin/perl -w
# This program tests network connections on the client side
# Author : H. Lang
# Date : 2017/10/10

#----------------------------------------------------------------------------------------
use strict;
use IO::Socket::INET;

#----------------------------------------------------------------------------------------
my $XYTEST  = "remote-conns";
my @servers = qw(server1.test761.com.:3306 server2.test761.com:3306 8.8.8.8:80);
my $server_status = "";
my $server;

my $debug = "no";
#my $debug = "yes";

#----------------------------------------------------------------------------------------
my %colours = ( green => 0,
               yellow => 1,
               red => 2
        );
my $colour = 'green';

use constant ERRTABLECELL => q{style="color:white;background-color:red"};
use constant WARNTABLECELL => q{style="color:white;background-color:yellow"};

use constant ERRTXTBEGIN => q{<span style="color:white;background-color:red">};
use constant ERRTXTEND => q{</span>};
use constant WARNTXTBEGIN => q{<span style="color:black;background-color:yellow">};
use constant WARNTXTEND => q{</span>};
use constant CLRTXTBEGIN => q{<span style="color:white;background-color:green">};
use constant CLRTXTEND => q{</span>};
use constant HITXTBEGIN => q{<span style="color:yellow">};
use constant HITXTEND => q{</span>};

#----------------------------------------------------------------------------------------
sub setcolour {
        my ($current, $new) = @_;
        return ($colours{$new} > $colours{$current}) ? $new : $current;
}

#----------------------------------------------------------------------------------------
sub connect_test {
  my ($input) = @_;
  my ($server,$port) = (split(/:/,$input));
  my $status = "green";

  if ( my $socket = new IO::Socket::INET ( PeerHost => "$server", PeerPort => "$port", Proto => 'tcp', Timeout => '3') ) {
    shutdown($socket, 1);
    $socket->close();
  }else{
    #$status = "red";
    $status = "green";
  }

  return ($status);
}

#----------------------------------------------------------------------------------------
#               MAIN
#----------------------------------------------------------------------------------------
my $date = localtime();

my $message = "<b><u>Outbound Connection Tests</u></b><br/>\n";
# You cannot use styles because it affect the whole xymon page.
#$message   .= "<style>table, th, td { border: 1px solid white; border-collapse: collapse; } </style>\n";
$message   .= "\n<table border=1 cellpadding=5 cellspacing=0 width=100%'>\n";
$message   .= "\n<tr><th width=200>Destination</th><th width=200>Status</th></tr>\n";

foreach $server (@servers) {
   ($server_status) = connect_test($server);
   if ($server_status eq 'red') {
#     $colour = setcolour($colour,'red');
     $colour = setcolour($colour,'yellow');
     $message .= "<tr><td ".ERRTABLECELL.">$server</td><td ".ERRTABLECELL.">Connection down </td></tr>\n";
   }else{
     $message .= "<tr><td>$server</td><td>Connection up </td></tr>\n";
   }
}

$message .= "</table>\n";

if ($debug eq "no") {
   exec "$ENV{XYMON}", "$ENV{XYMSRV}", "status+2h $ENV{MACHINE}.$XYTEST $colour $date\n$message\n\n";
} else {
   print "Colour : $colour\n";
   print "Date : $date\n";
   print "status $ENV{MACHINE}.$XYTEST $colour $date\n$message\n\n";
}
