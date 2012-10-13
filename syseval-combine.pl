#!/usr/bin/perl

use strict;
use utf8;
use FileHandle;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if(@ARGV == 0) {
    print STDERR "Usage: $0 REF EVAL_FILES...";
    exit 1;
}

my @handles;
for(@ARGV) {
   my $fh = IO::File->new("< $_") or die "didn't work for $_";
   binmode $fh, ":utf8";
   push @handles, $fh;
}

my $MAX_SIZE = 30;
my @lines;

while(1) {
    my ($ref, %vals);
    my $max = 0;
    foreach my $i (0 .. $#handles) {
        my $hand = $handles[$i];
        my $val = <$hand>;
        if(not $val) {
            print join("", shuffle(@lines));
            exit;
        }
        chomp $val;
        $val =~ s/ *$//g; $val =~ s/^ *//g;
        if($i == 0) { $ref = $val; }
        else        { $vals{$val}++; }
        $max = max(scalar(split(/ /, $val)), $max);
    }
    if($max <= $MAX_SIZE) {
        push @lines, ("$ref\t".join("\t\t", keys %vals)."\n");
    }
}
