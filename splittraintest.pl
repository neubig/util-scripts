#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use FileHandle;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV < 3) {
    print STDERR "Usage: $0 FRACTION TRAIN TEST [DEV]\n";
    exit 1;
}

my $fraction = $ARGV[0];
open TRAIN, ">:utf8", $ARGV[1] or die $!;
open TEST, ">:utf8", $ARGV[2] or die $!;
if(@ARGV == 4) {
    open DEV, ">:utf8", $ARGV[3] or die $!;
}

my $i = 0;
while(<STDIN>) {
    $i++;
    if(($i % $fraction) == 0) {
        print TEST $_;
    } elsif ((($i % $fraction) == 1) and (@ARGV == 4)) {
        print DEV $_;
    } else {
        print TRAIN $_;
    }
}
