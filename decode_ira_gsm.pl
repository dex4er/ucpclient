#!/usr/bin/perl -I/home/ucpgw/ucpclient

use UCP;

my $ucp = UCP->new or die;

my $cmd = $0;
$cmd =~ s{.*/}{};

if (@ARGV) {
    foreach (@ARGV) { print $ucp->$cmd($_), "\n"; }
}
else {
    while ($_ = <STDIN>) {
	chomp;
	print $ucp->$cmd($_), "\n";
    }
}

