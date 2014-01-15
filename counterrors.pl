#!/usr/bin/perl

# This is a script to count errors (insertions, deletions, substitutions)
# according to edit distance

use strict;
use warnings;
use utf8;
use List::Util qw(max min);
use FindBin;
use lib $FindBin::Bin;

use Levenshtein;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

if(@ARGV != 2) {
    print STDERR "Usage: counterrors.pl REFERENCE SYSTEM\n";
    exit;
}

# find which of the inputs are in error
open REF, "<:utf8", $ARGV[0] or die $!;
open TEST,    "<:utf8", $ARGV[1] or die $!;
my ($ref, $test, @refs, @tests, %errs, @hists);
while(defined($ref = <REF>) and defined($test = <TEST>)) {
    chomp $ref; chomp $test;
    my ($hist, $score) = Levenshtein::distance($ref, $test);
    @refs = split(/ +/, $ref);
    @tests = split(/ +/, $test);
    @hists = split(//, $hist);
    my (@rerr, @terr);
    while(@hists) {
        my $h = shift(@hists);
        if($h eq 'e') {
            if(@rerr+@terr) {
                my $err = (@rerr?join(' ',@rerr):"NULL")."\t".(@terr?join(' ',@terr):"NULL");
                $errs{$err}++;
                @rerr = ();
                @terr = ();
            }
            shift @refs; shift @tests;
        } else {
            push @rerr, shift(@refs) if $h ne 'i';
            push @terr, shift(@tests) if $h ne 'd';
        }
    }
    if(@rerr+@terr) {
        my $err = (@rerr?join(' ',@rerr):"NULL")."\t".(@terr?join(' ',@terr):"NULL");
        $errs{$err}++;
    }
}
close REF;
close TEST;

for(sort { $errs{$b} <=> $errs{$a} } keys %errs) {
    print "$_\t$errs{$_}\n";
}
