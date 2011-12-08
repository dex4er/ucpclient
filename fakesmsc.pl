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


my %counter;

sub show_stats {
    $ucp->debug(msg=>sprintf('%d msgs sent, %d msgs responsed',
        $counter{o}, $counter{r}));
}


sub SIGUSR1_handler {
    show_stats;
    $SIG{USR1} = \&SIGUSR1_handler;
}
$SIG{USR1} = \&SIGUSR1_handler;


sub connection {
    for (;;) {
        my $recv_msg = $ucp->recv;

        next unless defined $recv_msg;

        last if $recv_msg eq UCP::MSG_EOF;

        my $ref_msg = $ucp->parse_message($recv_msg);

        $counter{o}++ if $ucp->is_operation_message($ref_msg);
        $counter{r}++ if $ucp->is_result_message($ref_msg);

        if ($ref_msg->{type} eq UCP::OPERATION and $ref_msg->{ot} eq '51') {

            my $is_unknown = 0;
            my $is_positive = 1;
            if ($ref_msg->{amsg} =~ /^R51([+-])(\d+)/) {
                $is_positive = $1 eq '+' ? 1 : 0;
                my $delay = $2;
                sleep($delay);
            }

            my $sm = $ref_msg->{adc} . ':' . $ucp->make_scts;
            my $resp_msg = $ucp->make_message(
                op => '51',
                result => 1,
                trn => $ref_msg->{trn},
                ec => $is_positive ? '' : '02',
                ack => $is_positive ? UCP::ACK : undef,
                nack => $is_positive ? undef : UCP::NACK,
                sm => $is_positive ? $sm : ' Negative response requested',
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

            if ($ref_msg->{amsg} =~ /^O53([+\?-])(\d+)/) {
                $is_positive = $1 eq '+' ? 1 : 0;
                $is_unknown = $1 eq '?' ? 1 : 0;
                my $delay = $2;
                sleep($delay);
                # sm   => "503970092:241006090123"
                # scts =>           "241006090123"
                # id   =             061024090123
                my $scts;
                if ($sm =~ /^(?:\d+)?:(\d+)$/) {
                    $scts = $1;
                }
                else {
                    $scts = $ucp->make_scts;
                }
                $scts =~ /^(\d\d)(\d\d)(\d\d)(\d\d\d\d\d\d)$/;
                my $id = $3.$2.$1.$4;
                my $amsg = $is_positive ?
                    POSIX::strftime("Wiadomosc dla %%s, z identyfikatorem %%s zostala dostarczona %Y-%m-%d o %H:%M:%S.", localtime) :
                    ($is_unknown ?
                        "Wiadomosc dla %s, z identyfikatorem  %s nie mogla byc dostarczona z powodu  Unknown problem (kod 666)" :
                        "Wiadomosc dla %s, z identyfikatorem  %s nie mogla byc dostarczona z powodu  VP exceeded (kod 65283)");
                my $send_msg = $ucp->make_message(
                    op => '53',
                    operation => 1,
                    adc => $ref_msg->{oadc},
                    amsg => sprintf($amsg, $ref_msg->{adc}, $id),
                    mt => 3,
                    oadc => $ref_msg->{adc},
                    dst => $is_positive ? 0 : 2,
                    rsn => ($is_positive || $is_unknown) ? "000" : "108",
                    scts => $scts,
                    dscts => $ucp->make_scts,
                );
                $ucp->send($send_msg);
            }
        }

        elsif ($ref_msg->{type} eq UCP::OPERATION and $ref_msg->{ot} eq '60') {
            my $resp_msg;
            if ($ref_msg->{pwd} eq $opt{pwd}) {
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
                    sm => ' Password incorrect',
                );
            }
            $ucp->send($resp_msg);
        }
    }

}

while (defined($ucp->accept(\&connection))) { };

$ucp->shutdown;
