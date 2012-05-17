#!/usr/bin/perl

use strict;
use utf8;
use FileHandle;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV != 3) {
    print STDERR "Usage: $0 FRACTION TEST TRAIN\n";
    exit 1;
}

my $fraction = $ARGV[0];
open TEST, ">:utf8", $ARGV[1] or die $!;
if($ARGV[2]) {
    open TRAIN, ">:utf8", $ARGV[2] or die $!;
}

my $i = 0;
while(<STDIN>) {
    if($i++ % $fraction) {
        if($ARGV[2]) {
            print TRAIN $_;
        }
    }
    else {
        print TEST $_;
    }
}
