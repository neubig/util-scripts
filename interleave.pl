#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use FileHandle;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV == 0) {
    print STDERR "Usage: FILES";
    exit 1;
}

my @handles;
for(@ARGV) {
   my $fh = IO::File->new("< $_") or die "didn't work for $_";
   binmode $fh, ":utf8";
   push @handles, $fh;
}

while(1) {
    for(@handles) {
        my $val = <$_>;
        exit if not $val;
        print $val;
    }
    print "\n";
}
