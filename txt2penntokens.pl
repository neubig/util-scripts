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

if(@ARGV != 0) {
    print STDERR "Usage: $0\n";
    exit 1;
}

while(<STDIN>) {
    $_ =~ s/@/-AT-/g;
    $_ =~ s/" ([^"]+) "/`` $1 ''/g;
    $_ =~ s/\(/-LRB-/g;
    $_ =~ s/\)/-RRB-/g;
    $_ =~ s/\[/-LSB-/g;
    $_ =~ s/\]/-RSB-/g;
    $_ =~ s/\{/-LCB-/g;
    $_ =~ s/\}/-RCB-/g;
    $_ =~ s/\//\\\//g;
    print "$_";
}
