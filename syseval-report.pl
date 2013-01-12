#!/usr/bin/perl

use strict;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $LINES = -1;
my $COMPS = "0-1";
GetOptions(
    "lines=i" => \$LINES,
    "comps=s" => \$COMPS,
);

if(@ARGV != 2) {
    print STDERR "Usage: $0 TSV IDS\n";
    exit 1;
}
open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";

my ($stsv, $sids, $lines, @scores, @tsvs, @vals, @refs);
while(($stsv = <FILE0>) and ($sids = <FILE1>)) {
    ++$lines;
    last if ($LINES != -1) and ($lines > $LINES);
    chomp $stsv; chomp $sids;
    push @tsvs, $stsv;
    my @atsv = split(/\t/, $stsv);
    my @aids = split(/\t/, $sids);
    $refs[$lines-1] = shift(@atsv);
    $refs[$lines-1] .= "\t".shift(@atsv) if(@atsv % 2 == 1);
    if((max(@aids)+1)*2 != @atsv) { die "MISMATCHED LINES:\n$stsv\n$sids\n"; }
    foreach my $i (0 .. $#aids) {
        $scores[$i] = [] if not $scores[$i];
        push @{$scores[$i]}, $atsv[$aids[$i]*2+1];
        $vals[$i] = [] if not $vals[$i];
        push @{$vals[$i]}, $atsv[$aids[$i]*2];
    }
}

# for(split(/,/, $COMPS)) {
#    my ($base, $sys) = split(/-/);
# }

foreach my $i (1 .. scalar(@{$scores[0]})) {
    my @line = ($i, (map { $scores[$_]->[$i-1] } (0 .. $#scores)), (map { $vals[$_]->[$i-1] } (0 .. $#vals)), $refs[$i-1]);
    print join("\t", @line)."\n";
}
@scores = map { sum(@$_) / $lines } @scores;
print join("\t", "Total", @scores)."\n";
