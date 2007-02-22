#!/usr/bin/perl

use UCP;

my $ucp = UCP->new or die;

my $cmd = $0;
$cmd =~ s{.*/}{};
$cmd =~ s{\.pl$}{};

if (@ARGV) {
    foreach (@ARGV) { print $ucp->$cmd($_), "\n"; }
}
else {
    while ($_ = <STDIN>) {
	chomp;
	print $ucp->$cmd($_), "\n";
    }
}

