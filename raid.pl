#!/usr/bin/perl
# This program checks the status of the Hardware RAID card
# Author : H. Lang
# Date : 2012/06/01

#-------BB Variables----------------------------------------------------------
$BBPROG    = "raid.pl";
$BBTEST    = "raid";
$ENV{PATH} = "/bin:/usr/bin:/sbin";

$output    = "";
$colour    = "green";
$debug     = "no";
#$debug     = "yes";

$cmd_megaraid = "/opt/MegaRAID/MegaCli/MegaCli64 -CfgDsply -aALL";
#$cmd_megaraid = "/usr/local/sbin/MegaCli64 -CfgDsply -aALL";

#-----------------------------------------------------------------------------
sub report_to_bb {
# This subroutine checks the status and generates the BB output
  my (%info) = @_;
  my ($key, $drive);
  my $error = "";
  my (@date,$date);

  @date=localtime(time());
  $date=sprintf "%02i.%02i.20%02i %02i:%02i:%02i",$date[3],++$date[4],$date[5]-100,$date[2],$date[1],$date[0];

  foreach $key (keys %info) {
    #print"$key == $info{$key}\n";
    #----------Check for drive failures----------
    if (($key =~ /^[0-9]$/) and ("$info{$key}" ne "Online, Spun Up")) {
      if ("$info{$key}" eq "Rebuild") {
        $error = $error."Warning : Drive $key is rebuilding\n";
        if ("$colour" ne "red") {
          $colour = "yellow";
        }
      }else{
        $error = $error."Failure : Drive $key has failed\n";
        $colour = "red";
      }
    }
    #----------Check for S.M.A.R.T failures----------
    if (($key =~ /^[0-9] S.M.A.R.T$/) and ("$info{$key}" ne "No")) {
      $key =~ s/ .*//g; 
      $error = $error."Infomation : Drive $key flagged S.M.A.R.T\n";
    }
    #----------Check S.M.A.R.T Percentage----------
    if (($key =~ /^[0-9] smart_percent/) and ($info{$key} >= 90)) {
      $drive = $key; 
      $drive =~ s/ .*//g; 
      $error = $error."Warning : Drive $drive Percentage of S.M.A.R.T blocks used $info{$key}% > 90%\n";
      if ("$colour" ne "red") {
        $colour = "yellow";
      }
    }
    #----------Check for a volume failure----------
    if (($key =~ /^State/) and ("$info{$key}" ne "Optimal")) {
      $error = $error."Warning : The RAID volume is not Optimal\n";
      $colour = "red";
    }
    #----------Check for a battery failure----------
    if (($key =~ /^BBU/) and ("$info{$key}" ne "Present")) {
      $error = $error."Warning : The Cache Memory Battery is not Optimal\n";
      if ("$colour" ne "red") {
        $colour = "yellow";
      }
    }
    #----------get the parse output----------
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
    print "status $hostname.$BBTEST $colour $date\n$output\n\n";
  }
}

#-----------------------------------------------------------------------------
sub raid_info {
# This subroutine parse the raid information and generate a hash with the the status of the drives, volume and battery.

  my ($cmd) = @_;
  my %status;
  my $adphead = 1;
  my $output="-------------------------------------------------------\n";
  my $drive;

  foreach (`$cmd`) {
    chomp;
    #---------- Get the Adapter Information ----------
    if ($adphead) {
      if ( /^Product Name|^Memory/ ) {
        $output = $output."$_\n";
      }
    #---------- Get the Battery Status ----------
      if ( /^BBU: / ) {
        $output = $output."$_\n";
        ($key,$info) = (split(/: /,$_));
        $status{$key} = "$info";
        $adphead=0;
        $output = $output."-------------------------------------------------------\n";
      }
    }else{
    #---------- Get the Volume Information ----------
      if ( /^Number of|^Name|^RAID Level|^Size|^Number Of Drives/ ) {
        $output = $output."$_\n";
      }
    #---------- Get the Volume Status ----------
      if ( /^State\s+:/ ) {
        $output = $output."$_\n";
        ($key,$info) = (split(/: /,$_));
        $status{$key} = "$info";
      }
      if ( /^Number Of Drives/ ) {
        $output = $output."-------------------------------------------------------\n";
      }

    #---------- Get the Drive Information ----------
      if ( /^Physical Disk:/ ) {
        $output = $output."$_\n";
        $drive = (split(/: /,$_))[1];
      }
      if ( /^Raw Size|^Inquiry Data/ ) {
        $output = $output."$_\n";
      }
    #---------- Get the Drive Status ----------
      if ( /^Firmware state/ ) {
        $output = $output."$_\n";
        ($key,$info) = (split(/: /,$_));
        $status{$drive} = "$info";
      }
    #---------- Get the Drive S.M.A.R.T Status ----------
      if ( /^Predictive Failure Count/ ) {
        s/^Predictive Failure Count/S.M.A.R.T Failure Count/g;
        ($key,$info) = (split(/: /,$_));
        $status{$drive." smart_count"} = "$info";
        $output = $output."$_\n";
      }
      if ( /^Last Predictive Failure Event Seq Number/ ) {
        s/^Last Predictive Failure Event Seq Number/S.M.A.R.T Failure Limit/g;
        ($key,$info) = (split(/: /,$_));
        $status{$drive." smart_limit"} = "$info";
        $output = $output."$_\n";
      }
      if ( /^Drive has flagged a S.M.A.R.T alert/ ) {
        $output = $output."$_\n";
        ($key,$info) = (split(/: /,$_));
        $status{$drive." S.M.A.R.T"} = "$info";

        #---------- Get S.M.A.R.T percentage ----------
        if ( $status{$drive." smart_limit"} != 0 ) {
          $status{$drive." smart_percent"} = sprintf("%.2f", ($status{$drive." smart_count"} / $status{$drive." smart_limit"} * 100));
        }else{
          $status{$drive." smart_percent"} = 0;
        }
        $output = $output."Percentage S.M.A.R.T blocks used: $status{$drive.' smart_percent'}%\n";

        $output = $output."\n";
      }
    }
  }
  $output = $output."-------------------------------------------------------\n";
#  foreach $key (keys %status) {
#    print "$key == $status{$key}\n";
#  }
  $status{"output"} = "$output";
  return %status;
}

#-----------------------------------------------------------------------------
#       MAIN
#-----------------------------------------------------------------------------
%raid_info = raid_info("$cmd_megaraid");

report_to_bb(%raid_info);
