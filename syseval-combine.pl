#!/usr/bin/perl

#
# What's this?
# ------------
#
# This script allows you to combine multiple MT system outputs into a format
# suitable for manual evaluation. It should be used in combination with
# syseval-report.pl.
#
# Usage and Data Format
# ---------------------
#
# syseval-combine.pl               \
#            -src test.src         \
#            -ref test.trg         \
#            -ids output.ids       \
#            -min 1                \
#            -max 30               \
#            system-1.trg system-2.trg system-3.trg ... \
#            > output.csv
#
# Where test.src is the input, test.trg is the reference, output.ids is a
# list of ids used in syseval-report.pl. -min and -max are the minimum and
# maximum length of sentences to use in evaluation, and system-1.trg,
# system-2.trg, etc. are system output files. output.txt will be output in
# tab-separated format for reading into spreadsheet software such as Excel or
# OpenOffice Calc.
#
# Note that the output will be a tab-separated file with the reference and
# source first, followed by a system output and a blank space for entering
# its rating. The order of the system outputs will be randomized to prevent
# any effect of ordering on the decisions, and also identical hypotheses will
# be combined so the rater does not need to grade the same sentence twice.
# This order is saved in the output.ids file, and can be restored after the
# manual evaluation is finished by syseval-report.pl.

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
my $EM = "";   # If an exact match, output this
my $MAX = 999;
my $MIN = 1;
my $NUM = 0;
my $DUP = 0; # Allow duplicates
GetOptions(
    "ref=s" => \$REF,
    "src=s" => \$SRC,
    "ids=s" => \$IDS,
    "em=s" => \$EM,
    "max=i" => \$MAX,
    "min=i" => \$MIN,
    "num=i" => \$NUM,
    "dup" => \$DUP,
);

if(@ARGV == 0) {
    print STDERR "Usage: $0 EVAL_FILES...\n";
    exit 1;
}

my @handles;
my ($refh, $srch, $idsh);
for(@ARGV) {
   my $fh = IO::File->new("< $_") or die "Couldn't open $_";
   binmode $fh, ":utf8";
   push @handles, $fh;
}
die "Must define a reference -ref or a source -src" if not $REF and not $SRC;
my @title;
if($REF) {
    push @title, "Reference";
    $refh = IO::File->new("< $REF") or die "Couldn't open $REF";
    binmode $refh, ":utf8";
}
if($SRC) {
    push @title, "Source";
    $srch = IO::File->new("< $SRC") or die "Couldn't open $SRC";
    binmode $srch, ":utf8";
}
if($IDS) {
    $idsh = IO::File->new("> $IDS") or die "Couldn't open $IDS";
    binmode $idsh, ":utf8";
}
for(0 .. $#ARGV) {
    push @title, "Output", "Rating";
}
print join("\t", @title)."\n";

my @lines;

my %dups;
while(1) {
    my ($ref, $src, %vals, @valarr);
    my $len = 0;
    foreach my $i (0 .. $#handles) {
        my $hand = $handles[$i];
        my $val = <$hand>;
        if(not $val) {
            @lines = shuffle(@lines);
            @lines = @lines[0 .. $NUM-1] if $NUM;
            print join("\n", map {$_->[0]} @lines)."\n";
            print $idsh join("\n", map {$_->[1]} @lines)."\n" if $idsh;
            exit;
        }
        chomp $val;
        $val =~ s/ *$//g; $val =~ s/^ *//g;
        $vals{$val}++;
        push @valarr, $val;
    }
    if($refh) { $ref = <$refh>; chomp $ref; $ref =~ s/ +$//g; $len = scalar(split(/ /, $ref)); }
    if($srch) { $src = <$srch>; chomp $src; $src =~ s/ +$//g; $len = scalar(split(/ /, $src)); }
    if(($len <= $MAX) and ($len >= $MIN)) {
        my @cols;
        push @cols, $ref if $refh;
        push @cols, $src if $srch;
        my @shufvals = shuffle(keys %vals);
        foreach my $i (0 .. $#shufvals) {
            $vals{$shufvals[$i]} = $i;
            push @cols, $shufvals[$i], ((defined($ref) and ($shufvals[$i] eq $ref)) ? $EM : "");
        }
        my @valarr = map { $vals{$_} } @valarr;
        push @lines, [join("\t", @cols), join("\t", @valarr)] if $src and not ($dups{$src}++ and not $DUP);
    }
}
