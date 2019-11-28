#!/usr/bin/perl
# This program checks the status of the Hardware RAID card
# Author : H. Lang
# Date : 2012/06/01

#-------BB Variables----------------------------------------------------------
$BBPROG    = "iscsi.pl";
$BBTEST    = "iscsi";
$ENV{PATH} = "/bin:/usr/bin:/sbin";

$output    = "";
$colour    = "green";
$debug     = "no";
#$debug     = "yes";

$cmd_multipath = "/sbin/multipath -l";

#-----------------------------------------------------------------------------
sub report_to_bb {
# This subroutine checks the status and generates the BB output
  my (%info) = @_;
  my ($key, $volume, $path);
  my $error = "";
  my (@date,$date);

  @date=localtime(time());
  $date=sprintf "%02i.%02i.20%02i %02i:%02i:%02i",$date[3],++$date[4],$date[5]-100,$date[2],$date[1],$date[0];

  foreach $key (keys %info) {
    #print"$key == $info{$key}\n";
    #----------Check for volume failures----------
    if (($key =~ /status$/) and ($info{$key} !~ /active/)) {
      $key =~ s/ .*//g; 
      $error = $error."Failure : Volume $key is not active\n";
      $colour = "red";
    }
    #----------Check for path failures----------
    if (($key =~ / path /) and ($info{$key} !~ /active/)) {
      ($volume,$path) = (split(/ /,$key))[0,2];
      $error = $error."Warning : Volume $volume path $path is not active\n";
      if ("$colour" ne "red") {
        $colour = "yellow";
      }
    }
    #----------Get the parse output----------
    if ("$key" eq "output") {
      $output = "$info{$key}";
    }
  }

  #----------combine the error and parse output----------
  $output = $error."\n\n".$output;

  if ($debug eq "no") {
    exec "$ENV{XYMON}", "$ENV{XYMSRV}", "status $ENV{MACHINE}.$BBTEST $colour $date\n$output\n\n";
    #exec "$ENV{XYMON}", "--debug", "$ENV{XYMSRV}", "status $ENV{MACHINE}.$BBTEST $colour $date\n$output\n\n";
  } else {
    print "Colour : $colour\n";
    print "Date : $date\n";
    print "status $ENV{MACHINE}.$BBTEST $colour $date\n$output\n\n";
  }
}

#-----------------------------------------------------------------------------
sub multipath_info {
# This subroutine parse the multipath information and generate a hash with the the status of the paths.

  my ($cmd) = @_;
  my %status;
  my ($volume,$path,$temp);
  my $output="-------------------------------------------------------\n";

  foreach (`$cmd`) {
    chomp;
   #---------- Get Volume name ----------
    if ( / dm-[0-9]+ / ) {
      $output = $output."$_\n";
      $volume = $_;
      $volume =~ s/ .*//g;
    }
  #---------- Get Volume Status ----------
    if ( /^\\_ |^`-\+- / ) {
      $output = $output."$_\n";
      $status{$volume." status"} = "$_";
    }
  #---------- Get Path Status ----------
    if ( /^ \\_ |^  [\|`]- / ) {
      $output = $output."$_\n";
      ($path,$temp) = (split(/ +/,$_))[3,5];
      $status{$volume." path ".$path} = "$temp";
    }
  }
  $output = $output."-------------------------------------------------------\n";

  $status{"output"} = "$output";
  return %status;
}

#-----------------------------------------------------------------------------
#       MAIN
#-----------------------------------------------------------------------------
%multipath_info = multipath_info("$cmd_multipath");

report_to_bb(%multipath_info);
