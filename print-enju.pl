#!/usr/bin/perl

# *** print-enju.pl
# A script to visualize enju trees coming in from STDIN
# by Graham Neubig
#
# This script relies on Enju (of course):
# http://www.nactem.ac.uk/enju/
#
# And Hideki Isozaki's enjutree package:
# http://softcream.oka-pu.ac.jp/tex-macros/ 
#
# If the enjutree package is installed, you can parse a file
# and display the results one by one by running:
#
# enju -xml file.txt | print-enju.pl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $PDFLATEX = "pdflatex";
my $ACROREAD = "acroread";
GetOptions(
"acroread=s" => \$ACROREAD,
);

if(@ARGV != 0) {
    print STDERR "Usage: $0\n";
    exit 1;
}

while(<STDIN>) {
    chomp;
    open OUT, ">:utf8", "/tmp/enju.tex" or die "Couldn't open /tmp/enju.tex\n";
    print OUT "\\documentclass{article}\\usepackage{enjutree}\\begin{document}\n\\begin{enjutree}{}\n";
    print OUT "$_\n";
    print OUT "\\end{enjutree}\\end{document}\n";
    safesystem("$PDFLATEX -output-directory /tmp /tmp/enju.tex") or die;
    safesystem("$ACROREAD /tmp/enju.pdf") or die;
}


# Adapted from Moses's train-model.perl
sub safesystem {
  print STDERR "Executing: @_\n";
  system(@_);
  if ($? == -1) {
      print STDERR "ERROR: Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "ERROR: Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}
