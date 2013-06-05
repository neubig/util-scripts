#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use List::Util qw(sum min max shuffle);
use Getopt::Long;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $NOHYPHEN = 0;
my $NOSPACE = 0;
GetOptions(
    "nohyphen" => \$NOHYPHEN,
    "nospace" => \$NOSPACE,
);

if(@ARGV != 0) {
    print STDERR "Usage: han2zen.pl < INPUT > OUTPUT\n";
    exit 1;
}

while(<STDIN>) {
    tr/a-zA-Z0-9()[]{}<>.,_%｢｣､"?･+:｡!&*/ａ-ｚＡ-Ｚ０-９（）［］｛｝＜＞．，＿％「」、”？・＋：。！＆＊/;
    s/-/－/g if not $NOHYPHEN;
    s/ /　/g if not $NOSPACE;
    s/\//／/g;
    print $_;
}
