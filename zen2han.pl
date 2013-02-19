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
my $ZENSPACE = 0;
my $UNDERSPACE = 0;
my $TRIM = 0;
GetOptions(
    "nohyphen" => \$NOHYPHEN,
    "zenspace" => \$ZENSPACE,
    "underspace" => \$UNDERSPACE,
    "trim" => \$TRIM,
);

if(@ARGV != 0) {
    print STDERR "Usage: han2zen.pl < INPUT > OUTPUT\n";
    exit 1;
}

while(<STDIN>) {
    chomp;
    if($TRIM) { s/^ +//g; s/ +$//g; }
    tr/ａ-ｚＡ-Ｚ０-９（）［］｛｝＜＞．，＿％「」、”？・＋：。！＆＊/a-zA-Z0-9()[]{}<>.,_%｢｣､"?･+:｡!&*/;
    s/／/\//g;
    if(not $NOHYPHEN) { s/－/-/g; }
    if($ZENSPACE) { s/ /　/g; }
    elsif($UNDERSPACE) { s/　/__/g; }
    print "$_\n";
}
