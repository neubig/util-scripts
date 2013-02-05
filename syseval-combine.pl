#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use FileHandle;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $SRC = "";
my $REF = "";
my $IDS = "";
my $MAX = 30;
my $MIN = 1;
GetOptions(
    "ref=s" => \$REF,
    "src=s" => \$SRC,
    "ids=s" => \$IDS,
    "max=i" => \$MAX,
    "min=i" => \$MIN,
);

if(@ARGV == 0) {
    print STDERR "Usage: $0 EVAL_FILES...";
    exit 1;
}

my @handles;
my ($refh, $srch, $idsh);
for(@ARGV) {
   my $fh = IO::File->new("< $_") or die "didn't work for $_";
   binmode $fh, ":utf8";
   push @handles, $fh;
}
die "Must define a reference -ref or a source -src" if not $REF and not $SRC;
if($REF) {
   $refh = IO::File->new("< $REF") or die "didn't work for $_";
   binmode $refh, ":utf8";
}
if($SRC) {
   $srch = IO::File->new("< $SRC") or die "didn't work for $_";
   binmode $srch, ":utf8";
}
if($IDS) {
   $idsh = IO::File->new("> $IDS") or die "didn't work for $_";
   binmode $idsh, ":utf8";
}

my @lines;

while(1) {
    my ($ref, $src, %vals, @valarr);
    my $len = 0;
    if($refh) { $ref = <$refh>; chomp $ref; $len = split(/ /, $ref); }
    if($srch) { $src = <$srch>; chomp $src; $len = split(/ /, $src); }
    foreach my $i (0 .. $#handles) {
        my $hand = $handles[$i];
        my $val = <$hand>;
        if(not $val) {
            @lines = shuffle(@lines);
            print join("\n", map {$_->[0]} @lines)."\n";
            print $idsh join("\n", map {$_->[1]} @lines)."\n" if $idsh;
            exit;
        }
        chomp $val;
        $val =~ s/ *$//g; $val =~ s/^ *//g;
        $vals{$val}++;
        push @valarr, $val;
    }
    if(($len <= $MAX) and ($len >= $MIN)) {
        my @cols;
        push @cols, $ref if $refh;
        push @cols, $src if $srch;
        my @shufvals = shuffle(keys %vals);
        foreach my $i (0 .. $#shufvals) {
            $vals{$shufvals[$i]} = $i;
            push @cols, $shufvals[$i], "";
        }
        my @valarr = map { $vals{$_} } @valarr;
        push @lines, [join("\t", @cols), join("\t", @valarr)];
    }
}
