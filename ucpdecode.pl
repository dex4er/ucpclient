#!/usr/bin/perl

use strict;
use UCP;


our $ucp = UCP->new or die;


sub dump_message {
    my $msg = shift;
    
    print "<<< $msg\n";
    my $ref_msg = $ucp->parse_message($msg);

    print $ucp->dump($ref_msg);
    print "\n\n";
}


if (@ARGV) {
    foreach my $msg (@ARGV) {
	dump_message $msg;
    }
}
else {
    my $msg = "";
    while (my $line = <STDIN>) {
        chomp $line;
	if ($line ne "") {
	    $msg .= $line;
	}
	else {
	    $msg =~ s{^\D*(\d\d/)}{$1};
	    $msg =~ s{(/\d\d)\D*$}{$1};
	    dump_message $msg;
	    $msg = "";
	}
    }
    dump_message $msg if $msg ne "";
}
