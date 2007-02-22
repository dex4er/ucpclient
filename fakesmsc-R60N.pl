#!/usr/bin/perl

use strict;
use UCP;


my %opt = ();

while (@ARGV) {
    if ($ARGV[0] =~ m/^(.*)=(.*)$/) {
        $opt{$1} = $2;
        shift;
    }
}

$opt{DebugLevel} = 2 unless exists $opt{DebugLevel};
$opt{DebugId} = 'S' unless exists $opt{DebugId};

my $ucp = UCP::Socket->new(%opt) or die;


sub connection {
    for (;;) {
        my $recv_msg = $ucp->recv;

        next unless defined $recv_msg;

        last if $recv_msg eq UCP::MSG_EOF;

        my $ref_msg = $ucp->parse_message($recv_msg);

        if ($ref_msg->{type} eq UCP::OPERATION and $ref_msg->{ot} eq '51') {
            my $resp_msg = $ucp->make_message(
                op => '51',
                result => 1,
                trn => $ref_msg->{trn},
                ack => UCP::ACK,
                sm => $ref_msg->{adc} . ':' . $ucp->make_scts,
            );
            $ucp->send($resp_msg);

            if ($ref_msg->{amsg} eq 'AnswerMe') {
                my $send_msg = $ucp->make_message(
                    op => '52',
                    operation => 1,
                    adc => $ref_msg->{oadc},
                    amsg => 'Re:' . $ref_msg->{amsg},
                    mt => 3,
                    oadc => $ref_msg->{adc},
                    dcs => 0,
                    rpid => '0000',
                    scts => $ucp->make_scts,
                );

                $ucp->send($send_msg);
            }
        }

        elsif ($ref_msg->{type} eq UCP::OPERATION and $ref_msg->{ot} eq '60') {
	    my $resp_msg;
	    if (0 and $ref_msg->{pwd} eq 'pwd') {
        	$resp_msg = $ucp->make_message(
            	    op => '60',
                    result => 1,
                    trn => $ref_msg->{trn},
                    ack => UCP::ACK,
                );
	    }
	    else {
        	$resp_msg = $ucp->make_message(
            	    op => '60',
                    result => 1,
                    trn => $ref_msg->{trn},
                    nack => UCP::NACK,
		    ec => '04',
                    sm => 'Password incorrect',
                );
	    }
            $ucp->send($resp_msg);
        }
    }

}

while (defined($ucp->accept(\&connection))) { };

$ucp->shutdown;
