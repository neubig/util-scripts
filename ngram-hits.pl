#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $N = 4;
GetOptions(
    "n=i" => \$N,
);

if(@ARGV != 2) {
    print STDERR "Usage: $0 REF SYS\n";
    exit 1;
}

open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";

sub count_ngrams {
    my %ret;
    my @arr = split(/ /, $_[0]);
    foreach my $i (0 .. $#arr) {
        my @str;
        foreach my $j ($i .. min($#arr, $i+$N-1)) {
            push @str, $arr[$j];
            $ret{"@str"}++;
        }
    }
    return %ret;
}

my %total;
my ($s0, $s1);
while(defined($s0 = <FILE0>) and defined($s1 = <FILE1>)) {
    chomp $s0; chomp $s1;
    my %n0 = count_ngrams($s0);
    my %n1 = count_ngrams($s1);
    for(keys %n0) {
        if($n1{$_}) {
            $total{$_} += min($n0{$_}, $n1{$_});
        }
    }
}

for(sort { $total{$b} <=> $total{$a} } keys %total) {
    print "$_\t$total{$_}\n";
}
