#!/usr/bin/perl

# This is a script to tabulate the errors made by two systems
#  In order to use it first run counterrors.pl on two different system outputs
#
# $ counterrors.pl ref.txt test-1.txt > test-1.err
# $ counterrors.pl ref.txt test-2.txt > test-2.err
# 
# Next, run this script on the error files to get the output
#
# $ error-diff.pl test-1.err test-2.err > test-diff.err
#
# test-diff.err will now contain error examples along with frequencies.
# examples with positive frequencies are more common in the first file,
# while examples with negative frequencies are more common in the second file.

use strict;
use warnings;
use utf8;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
use List::Util qw(sum min max shuffle);

if(@ARGV != 2) {
    print STDERR "Usage: error-diff.pl file1.err file2.err\n";
    exit 1;
}

my %vals;
open FILE, "<:utf8", $ARGV[0] or die "$ARGV[0]: $!\n";
while(<FILE>) {
    chomp;
    /(.*)\t([0-9]*)$/;
    $vals{$1} += $2;
}
close FILE;
open FILE, "<:utf8", $ARGV[1] or die "$ARGV[1]: $!\n";
while(<FILE>) {
    chomp;
    /(.*)\t([0-9]*)$/;
    $vals{$1} -= $2;
}
close FILE;

for(sort {$vals{$b} <=> $vals{$a}} keys %vals) {
    print "$_\t$vals{$_}\n" if $vals{$_};
}
