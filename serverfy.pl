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
$RPC::XML::FORCE_STRING_ENCODING = 1;

my $PORT = 9002;
my $TIMEOUT = 20;
GetOptions(
"port=s" => \$PORT,
"timeout=s" => \$TIMEOUT,
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
    # Remove bad unicode and the optional <req> header
    utf8::decode($t);
    $t =~ tr[\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}][]cd;
    utf8::encode($t);
    return "" if $t =~ /^ *$/;
    # Send this to the processor
    print STDERR "IN: $t\n";
    print Writer "$t\n";
    my $got;
    eval {
        local $SIG{ALRM} = sub { die "ALARUM" };
        alarm($TIMEOUT);
        chomp($got = <Reader>);
        alarm(0);
    };
    if ($@ =~ /ALARUM/) { 
        close Writer or die $!;
        close Reader or die $!;
        waitpid($pid, 0);
        $pid = open2(*Reader, *Writer, $ARGV[0]) or die "Could not run $ARGV[0]\n";
        return "__FAILURE__: Timeout of $TIMEOUT seconds reached, restarting.";
    }
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
$srv->add_method({ name => 'process', code => \&run_cmd, signature => [ 'string string' ] });

# サーバーを立ち上げる
$srv->server_loop;
