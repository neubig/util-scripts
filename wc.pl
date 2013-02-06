#!/usr/bin/perl

$| = 1;

use strict;
use warnings;
use utf8;
use FileHandle;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV == 0) {
    my ($l, $w, $c);
    while(<STDIN>) {
        chomp;
        $l++;
        $c += length($_);
        $w += split(/ /);
    }
    print "$l $w $c\n";
} else {
    foreach my $f (@ARGV) {
        open FILE, "<:utf8", $f or die "Couldn't open $f";
        my ($l, $w, $c);
        while(<FILE>) {
            chomp;
            $l++;
            $c += length($_);
            $w += split(/ /);
        }
        print "$l $w $c\t$f\n";
    }
}
