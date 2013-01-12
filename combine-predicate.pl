#!/usr/bin/perl

use strict;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV != 0) {
    print STDERR "Usage: $0\n";
    exit 1;
}

sub iscombine {
    my $s = shift;
    print "$s\n";
    my ($word, $pos, $pron) = split(/\//, $s);
    if($pos =~ /^(語尾|助動詞)$/) {
        return 1;
    } elsif(($word =~ /^(て)$/) and ($pos =~ /^(助詞)$/)) {
        return 1;
    } elsif(($word =~ /^(し|す|あ|い|な)$/) and ($pos =~ /^(動詞)$/)) {
        return 1;
    }
    return 0;
}

while(<STDIN>) {
    chomp;
    my @warr = split(/ /);
    my @harr = map { /^([^\/]+)/; $1 } @warr;
    my @carr = map { iscombine($_) } @warr;
    my @newarr = ($harr[0]);
    foreach my $i (1 .. $#warr) {
        if(($carr[$i] == 1) and ($carr[$i-1] == 1)) {
            $newarr[-1] .= $harr[$i];
        } else {
            push @newarr, $harr[$i];
        }
    }
    print "@newarr\n";
    
}
