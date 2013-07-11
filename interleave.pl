#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use IO::File;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $NOSPACE = 0;
GetOptions(
    "nospace" => \$NOSPACE,
);

if(@ARGV == 0) {
    print STDERR "Usage: FILES\n";
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
    print "\n" if not $NOSPACE;
}
