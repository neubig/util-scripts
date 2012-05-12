#!/usr/bin/perl

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my %count;
while(<STDIN>) {
    chomp;
    for(split(/ /)) {
        $count{$_}++;
    }
}

foreach my $k (sort {$count{$b}<=>$count{$a}} keys %count) {
    print "$k\t$count{$k}\n";
}
