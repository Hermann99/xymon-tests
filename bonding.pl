#!/usr/bin/perl
# This program checks the status of the iscsi connections and iscsi network ports
# Author : H. Lang
# Date : 2010/08/12

#-------BB Variables----------------------------------------------------------
$BBDISP    = "bb.smp.mweb.co.za";
$hostname  = "$ENV{HOSTNAME}";

$BBPROG    = "check_iscsi.pl";
$BBTEST    = "iscsi";
#$BBHOME    = "/usr/local/bb";
$ENV{PATH} = "/bin:/usr/bin:/sbin";

$output    = "";
$colour    = "green";
#$debug     = "yes";
$debug     = "no";

$cmd_mount    = "/bin/mount";
$cmd_udevinfo = "/usr/bin/udevinfo";
$bond_file    = "/proc/net/bonding/bond0";

#-----------------------------------------------------------------------------
sub report_to_bb {
  my (@date,$date);
  @date=localtime(time());
  $date=sprintf "%02i.%02i.20%02i %02i:%02i:%02i",$date[3],++$date[4],$date[5]-100,$date[2],$date[1],$date[0];

  foreach $key (keys %bond_info) {
    if (($key =~ /^eth/) and ("$bond_info{$key}" ne "up")) {
      $colour = "yellow";
      $error = "FAILURE : One of the network paths is down\n";
    }elsif (($key =~ /^bond/) and ($bond_info{$key} !~ /up$/)) {
      $colour = "red";
      $error = "FAILURE : The bonded interface is down\n";
    }
  }
  $output = "Mount Point             EqualLogic Volume\n";
  $output = $output."-----------------------------------------------------------------------------------------------------------\n";
  foreach $key (sort {$a cmp $b} keys %vol_info) {
    $output = $output."$key      $vol_info{$key}\n";
  }
  $output = $output."\nNetwork Bond Status\n";
  $output = $output."-------------------\n";
  $output = $output."$error";
  foreach $key (sort {$a cmp $b} keys %bond_info) {
    if ($key =~ /^bond/) {
      $output = $output."$key : $bond_info{$key}\n";
    }else{
      $output = $output."    Slave Interface $key : $bond_info{$key}\n";
    }
  }

  if ($debug eq "no") {
    system("$ENV{BB} $ENV{BBDISP} \"status $ENV{MACHINE}.$BBTEST $colour $date\n$output\"");
  } else {
    print "Colour : $colour\n";
    print "Date : $date\n";
    print "status $hostname.$BBTEST $colour $date\n$output\n\n";
  }
}

#-----------------------------------------------------------------------------
sub vol_info {
  my ($cmd_mount,$cmd_udevinfo) = @_;
  my ($line,$dev,$mount,$name,$entry,$iqn);
  my %vol_info;

  foreach $line (`$cmd_mount`) {
    chomp ($line);
    if ( $line =~ /virtual\/store/ ) {
      ($dev,$mount) = (split(/ /,$line))[0,2];  
      $name = $dev;
      $name =~ s/.*\///g;
      foreach $entry (`$cmd_udevinfo -q env -n $name`) {
        chomp ($entry);
        if ( $entry =~ /-iscsi-iqn/ ) {
          $entry =~ s/.*-iscsi-iqn./iqn./g;
          $iqn = $entry;
        }
      }
      $vol_info{$mount} = $iqn;
      #print "$mount : $dev : $name : $iqn\n";
    }
  }
  return %vol_info;
}

#-----------------------------------------------------------------------------
sub bond_info {
  my ($bond_file) = @_;
  my ($bond,$eth,$status,$bond_status,%interface);

  open (FILE,"$bond_file");

  while (<FILE>) {
    chomp;
    if ( /^Bonding Mode:/ ) {
      s/^Bonding Mode: //g;
      $bond = $_;
    }
    if ( /^Slave Interface:/ ) {
      s/^Slave Interface: //g;
      $eth = $_;
    }
    if ( /^MII Status:/ ) {
      s/^MII Status: //g;
      $status = $_;
    }
    if ( /^Permanent HW/ ) {
      $interface{"$eth"} = "$status";
    }
    if ( /^MII Polling/ ) {
      #$bond_status = "$bond  $status";
      $interface{"bond0"} = "$bond : $status";
    }
  }
  close (FILE);
  return %interface;
}

#-----------------------------------------------------------------------------
#       MAIN
#-----------------------------------------------------------------------------
%vol_info  = vol_info("$cmd_mount","$cmd_udevinfo");
%bond_info = bond_info("$bond_file");

report_to_bb();
