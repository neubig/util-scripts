#!/usr/bin/perl
use strict;
use warnings;
use Test::Simple tests => 1;

require 'levenshtein.pl';

# TODO: Write tests about levenshtein().
# this is a dummy test.
my $a = "test";
my $b = "test";
ok($a eq $b);
