#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV > 1) {
    print STDERR "Usage: $0 [GLUE]\n";
    exit 1;
}

my $GLUE = $ARGV[0];

sub wpp {
    my $s = shift;
    $s =~ /^(.+)\/([^\/]+)\/([^\/]+)$/ or die $s;
    return ($1, $2, $3);
}

sub iscombine {
    my $s = shift;
    my ($word, $pos, $pron) = wpp($s);
    print "word=$word\tpos=$pos\tpron=$pron\n";
    if($pos =~ /^(語尾|助動詞)$/) {
        return 1;
    } elsif(($word =~ /^(て|ば)$/) and ($pos =~ /^(助詞)$/)) {
        return 1;
    } elsif(($word =~ /^(な)$/) and ($pos =~ /^(形容詞)$/)) {
        return 1;
    } elsif(($word =~ /^(し|す|あ|い)$/) and ($pos =~ /^(動詞)$/)) {
        return 1;
    }
    return 0;
}

while(<STDIN>) {
    chomp;
    my @warr = split(/ /);
    my @harr = map { my ($w, $pr, $ps) = wpp($_); $w } @warr;
    my @carr = map { iscombine($_) } @warr;
    my @newarr = ($harr[0]);
    foreach my $i (1 .. $#warr) {
        if(($carr[$i] == 1) and ($carr[$i-1] == 1)) {
            $newarr[-1] .= $GLUE . $harr[$i];
        } else {
            push @newarr, $harr[$i];
        }
    }
    print "@newarr\n";
    
}
