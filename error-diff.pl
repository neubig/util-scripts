#!/usr/bin/perl

use strict;
use utf8;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
use List::Util qw(sum min max shuffle);

if(@ARGV != 2) {
    print STDERR "Usage: error-diff.pl file1.err file2.err";
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
