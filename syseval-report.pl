#!/usr/bin/perl

use strict;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $LINES = -1;
GetOptions(
    "lines=i" => \$LINES,
);

if(@ARGV != 2) {
    print STDERR "Usage: $0 TSV IDS\n";
    exit 1;
}
open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";

my ($stsv, $sids, $lines, @scores);
while(($stsv = <FILE0>) and ($sids = <FILE1>)) {
    ++$lines;
    last if ($LINES != -1) and ($lines > $LINES);
    chomp $stsv; chomp $sids;
    my @atsv = split(/\t/, $stsv);
    my @aids = split(/\t/, $sids);
    shift @atsv;
    shift @atsv if(@atsv % 2 == 1);
    if((max(@aids)+1)*2 != @atsv) { die "MISMATCHED LINES:\n$stsv\n$sids\n"; }
    foreach my $i (0 .. $#aids) {
        $scores[$i] = [] if not $scores[$i];
        push @{$scores[$i]}, $atsv[$aids[$i]*2+1];
    }
}

@scores = map { sum(@$_) / $lines } @scores;
print "@scores\n";
