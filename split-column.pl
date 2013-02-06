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

if(@ARGV != 1) {
    print STDERR "Usage: $0\n";
    exit 1;
}

while(<STDIN>) {
    chomp;
    my @arr = split(/\t/);
    print "$arr[$ARGV[0]]\n";
}
