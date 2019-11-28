#! /usr/bin/perl -w
# RAID and drive monitoring for Dell servers
# Works with mfi and older amr disks.  Unfortunately
# mfiutil is not available for FreeBSD < 8, so this won't
# work on 2950's with FreeBSD 7.x
use strict;

use constant ERRTXTBEGIN => q{<span style=\"color:white;background-color:red\">};
use constant ERRTXTEND => q{</span>};
use constant WARNTXTBEGIN => q{<span style=\"color:black;background-color:yellow\">};
use constant WARNTXTEND => q{</span>};
use constant CLRTXTBEGIN => q{<span style=\"color:white;background-color:green\">};
use constant CLRTXTEND => q{</span>};
use constant HITXTBEGIN => q{<span style=\"color:yellow\">};
use constant HITXTEND => q{</span>};

my $xymon_column = 'raid';

my %colors = (
                green => 0,
                yellow => 1,
                red => 2,
        );
my $color = 'green';

my $message = "";

# Check if I need to use mfiutil or amrstat
if (-c '/dev/mfi0') {
        my $mfi_cmd = '/usr/sbin/mfiutil';
        my $mfi_drives  = "$mfi_cmd show drives";
        my $mfi_volumes = "$mfi_cmd show volumes";

        if (! -e $mfi_cmd) {
                $message = WARNTXTBEGIN."$mfi_cmd is not installed on this machine".WARNTXTEND;
                $color = 'yellow';
                my $date = localtime();
                system("$ENV{BB} $ENV{BBDISP} \"status $ENV{MACHINE}.$xymon_column $color $date\n$message\"");
                exit;
        } else {
                my @vol_state = qx($mfi_volumes);
                for (@vol_state) {
                        #  mfid0 (  136G) RAID-1      64K OPTIMAL Disabled
                        if (/^\s*([a-z0-9]+)\s+\(\s*(\d+[MGT])\)\s+(\S+)\s+(\d+\S)\s+(\S+)/) {
                                #print "$1 $2 $3 $4 $5\n";
                                if ($5 ne 'OPTIMAL') {
                                        $message .= ERRTXTBEGIN.$_.ERRTXTEND;
                                        $color = setcolor($color,'red');
                                } else {
                                        $message.= $_;
                                }
                        } else {
                                $message.=$_;
                        }
                }
                my @drive_state = qx($mfi_drives);
                for (@drive_state) {
                        # (  137G) ONLINE <SEAGATE ST3146356SS HS10 serial=3QN47NA3> SAS enclosure 1, slot 0
                        if (/^\s*\(\s*(\d+[GMT])\)\s*(\S+)\s*/) {
                                #print "$1 $2\n";
                                if ($2 ne 'ONLINE') {
                                        $message .= ERRTXTBEGIN.$_.ERRTXTEND;
                                        $color = setcolor($color,'red');
                                } else {
                                        $message.= $_;
                                }
                        } else {
                                $message.=$_;
                        }
                }
        }
} elsif (-c '/dev/amr0') {
        my $amrstat = '/usr/local/sbin/amrstat';
        if (! -e $amrstat) {
                $message = WARNTXTBEGIN."$amrstat is not installed on this machine".WARNTXTEND;
                $color = 'yellow';
                my $date = localtime();
                system("$ENV{BB} $ENV{BBDISP} \"status $ENV{MACHINE}.$xymon_column $color $date\n$message\"");
                exit;
        } else {
                my @amrstatus = qx($amrstat);
                for (@amrstatus) {
                        if (/Logical volume \d+:\s*(\S+)\s/) {
                                if ($1 ne 'optimal') {
                                        $message .= ERRTXTBEGIN.$_.ERRTXTEND;
                                        $color = setcolor($color,'red');
                                } else {
                                        $message.= $_;
                                }
                        } elsif (/Physical drive \d+:\d+\s+(\S+)\s/) {
                                if ($1 !~ /(online|hotspare)/) {
                                        $message .= ERRTXTBEGIN.$_.ERRTXTEND;
                                        $color = setcolor($color,'red');
                                } else {
                                        $message.= $_;
                                }
                        } else {
                                $message.=$_;
                        }
                }
        }
} else {
        print "No suitable drive types (amr/mfi) found on this server - exiting\n";
        exit;
}


if ($color ne 'green') {
        $message .= '<br/>'.ERRTXTBEGIN.'RAID Failures detected'.ERRTXTEND;
} else {
        $message .= '<br/>'.CLRTXTBEGIN.'All drives/volumes ok'.CLRTXTEND;
}

my $date = localtime();
system("$ENV{BB} $ENV{BBDISP} \"status $ENV{MACHINE}.$xymon_column $color $date\n$message\"");
#print $message;

sub setcolor {
        my ($current, $new ) = @_;
        return ($colors{$new} > $colors{$current}) ? $new : $current;
}
