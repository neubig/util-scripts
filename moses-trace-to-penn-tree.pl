#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my (@sentences, @roots);
while(<STDIN>) {
    chomp;
    /^Trans Opt (\d+) (\[\d+\.\.\d+\]): (.*)$/ or die "Bad $_\n";
    my ($sent, $span, $value) = ($1, $2, $3);
    if(not $sentences[$sent]) {
        $roots[$sent] = $span;
        $sentences[$sent] = {}
    }
    $sentences[$sent]->{$span} = $value;
}

sub span2josh {
    my $str = shift;
    $str =~ /^\[(\d+)\.\.(\d+)\]$/ or die "bad moses span $str\n";
    return "{$1-".($2+1)."}";
}

sub print_tree {
    my ($tree, $span) = @_;
    my $val = $tree->{$span};
    $val =~ /^((\[\d+\.\.\d+\]=\S* +)+): ([A-Z]+) ->(.*):((\d+-\d+ )*): pC=/ or die "bad $val\n";
    my ($tags, $head, $tails, $correspond) = ($1, $3, $4, $5);
    $tails =~ s/ +$//g; $correspond =~ s/ +$//g;
    my @spans = reverse map { my @arr = split(/=/); $arr[0] } split(/ +/, $tags);
    my @srcs = reverse map { my @arr = split(/=/); $arr[1] } split(/ +/, $tags);
    my @tails = split(/ /, $tails);
    my %t2s;
    my @correspond = map { my @arr = split(/-/); $t2s{$arr[1]} = $arr[0]; \@arr } split(/ +/, $correspond);
    # Label the source side values
    my $id = 0;
    for(sort { $a->[1] <=> $b->[1] } @correspond) {
        $srcs[$_->[0]] .= ++$id;
    }
    my $ret = "(".join("_",@srcs);
    foreach my $i ( 0 .. $#tails ) {
        $ret .= " ";
        if(exists $t2s{$i}) {
            $ret .= print_tree($tree, $spans[$t2s{$i}]);
        } else {
            $ret .= "(W $tails[$i])";
        }
    }
    $ret .= ")";
    return $ret;
}

for(0 .. $#sentences) {
    print print_tree($sentences[$_], $roots[$_])."\n";
}
