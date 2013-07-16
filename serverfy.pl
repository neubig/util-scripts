#!/usr/bin/perl

use strict;
use utf8;
use Getopt::Long;
use RPC::XML::Server;
use MIME::Base64;
use File::Basename;
use List::Util qw(sum min max shuffle);
use FileHandle;
use IPC::Open2;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

$RPC::XML::ENCODING = 'utf-8';

my $PORT = 9002;
GetOptions(
"port=s" => \$PORT,
);

if(@ARGV != 1) {
    print STDERR "Usage: $0\n";
    exit 1;
}

print STDERR "Serverfying:\n$ARGV[0]\n";
my $pid = open2(*Reader, *Writer, $ARGV[0]) or die "Could not run $ARGV[0]\n";

# 関数を追加
sub run_cmd {
    my $s = shift; # サーバーオブジェクト
    my $t = shift; # txt name
    print STDERR "IN: $t\n";
    print Writer "$t\n";
    my $got = <Reader>;
    chomp $got;
    my $pr = $got;
    utf8::decode($pr);
    print STDERR "OUT: $pr\n";
 	return $got;
}

# サーバーの情報を初期化
my $srv = RPC::XML::Server->new(port => $PORT);

# メソッドを構築
my $ls_method = RPC::XML::Procedure->new();

# メソッドを追加
$srv->add_method(
    { name => 'process',
      code => \&run_cmd,
      signature => [ 'string string' ] }
);

# サーバーを立ち上げる
$srv->server_loop;
