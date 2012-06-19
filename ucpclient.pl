#!/usr/bin/perl

use strict;
use Time::HiRes qw(gettimeofday tv_interval);
use List::Util qw(max);
use UCP;


my %opt = ();
while (@ARGV) {
    if ($ARGV[0] =~ m/^(.*?)=(.*)$/) {
        $opt{$1} = $2;
        shift;
    }
}

my @adc = split /,/, $opt{adc};
my @oadc = split /,/, $opt{oadc} if $opt{oadc} =~ /^[\d,]+$/;

$opt{Requests} = max(scalar @adc, scalar @oadc) || 1 unless exists $opt{Requests};

$opt{ParserHook} = \&parser_hook;
$opt{SenderHook} = \&sender_hook;
$opt{ReceiverHook} = \&receiver_hook;

$opt{DebugLevel} = 2 unless exists $opt{DebugLevel};
$opt{DebugId} = 'C' unless exists $opt{DebugId};

my $ucp = UCP::Manager->new(%opt) or die;


sub o_51 {
    return $ucp->make_message(
        %opt,
        trn       => '00',
        op        => exists $opt{op} ? $opt{op} : 51,
        operation => 1,
        mt        => exists $opt{mt} ? $opt{mt} : 3,
    );
}


sub o_60 {
    return $ucp->make_message(
        trn       => '00',
        op        => 60,
        operation => 1,
        pwd       => $opt{pwd},
        onpi      => 5,
        oton      => 6,
        styp      => 1,
        vers      => '0100',
        oadc      => $opt{LA} || $opt{oadc},
    );
}


sub r_60_a {
    my $ref_msg = shift;
    return $ucp->make_message(
            op => $ref_msg->{ot},
            result => 1,
            trn => $ref_msg->{trn},
            ack => UCP::ACK,
    );
}


sub r_xx_a {
    my $ref_msg = shift;
    return $ucp->make_message(
            op => $ref_msg->{ot},
            result => 1,
            trn => $ref_msg->{trn},
            ack => UCP::ACK,
            sm => $ref_msg->{adc} . ':' . $ucp->make_scts,
    );
}


sub r_xx_n {
    my $ref_msg = shift;
    return $ucp->make_message(
            op => $ref_msg->{ot},
            result => 1,
            trn => $ref_msg->{trn},
            nack => UCP::NACK,
            ec => printf("%02d", defined $opt{ec} ? $opt{ec} : 4),
            sm => ' '.$ucp->ec_string('04'),
    );
}


my %counter : shared = ();
my $is_authorized : shared = 0;


sub sender_hook {
    my $self = shift;
    my $msg = shift;
    $counter{o}++ if $self->is_operation_message($msg);
    return $msg;
}


sub parser_hook {
    my $self = shift;
    my $msg = shift;
    my $ref_msg = $self->parse_message($msg);
    if ($self->is_result_message($ref_msg) and $ref_msg->{ot} eq '51') {
        $counter{r_51}++;
        $counter{r_51_ack}++ if exists $ref_msg->{ack} and $ref_msg->{ack} eq UCP::ACK;
    }
    elsif ($self->is_result_message($ref_msg) and $ref_msg->{ot} eq '60') {
        $is_authorized = $ref_msg->{ack} ? 1 : 0;
    }
    elsif ($self->is_operation_message($ref_msg) and $ref_msg->{ot} eq '60') {
        $self->send(r_60_a($ref_msg));
    }
    else {
        $counter{unknown}++;
        if ($self->is_operation_message($ref_msg)) {
            if (defined $opt{ec} and $opt{ec} > 0 or not defined $opt{ec}) {
                $self->send(r_xx_n($ref_msg));
            }
            else {
                $self->send(r_xx_a($ref_msg));
            }
        }
    }
    return $msg;
}


sub receiver_hook {
    my $self = shift;
    my $msg = shift;
    return $msg;
}


sub show_stats {
    $ucp->debug(msg=>sprintf('%d msgs sent, %d msgs responsed, %d msgs ack, %d msgs unknown',
        $counter{o}, $counter{r_51}, $counter{r_51_ack}, $counter{unknown}));
}


sub SIGUSR1_handler {
    show_stats;
    $SIG{USR1} = \&SIGUSR1_handler;
}
$SIG{USR1} = \&SIGUSR1_handler;


sub main {
    $ucp->create;

    my $t0 = [gettimeofday] if $opt{Benchmark};
    my $elapsed = 0;

    TRANSFER: {

        if ($opt{pwd}) {
            $ucp->send(o_60);
            $ucp->wait_all_trn;
            select(undef,undef,undef,1); # wait for parser
            last unless $is_authorized;
        }

        if (exists $opt{op} && $opt{op} eq "52" && exists $opt{oadc}) {
            $opt{Msisdn} = $opt{oadc};
        } else {
            $opt{Msisdn} = $opt{adc};
        }
        for (my $n = 0; $n < $opt{Requests}; $n++) {
            $opt{adc} = shift @adc if @adc;
            $opt{oadc} = shift @oadc if @oadc;
            $ucp->send(o_51) or last;
            select(undef, undef, undef, $opt{Delay}) if $opt{Delay};
            $ucp->wait_free_trn;

            if ( exists $opt{Inc} && $opt{Inc} ) {
                if ((exists $opt{op} && $opt{op} eq "51" || ! exists $opt{op}) && exists $opt{adc}) {
                    if ($opt{Mod}) {
                        $opt{adc} = $opt{Msisdn} + ($n * $opt{Inc}) % $opt{Mod};
                    } else {
                        $opt{adc} = $opt{Msisdn} + $n * $opt{Inc};
                    }
                }
                if (exists $opt{op} && $opt{op} eq "52" && exists $opt{oadc}) {
                    if ($opt{Mod}) {
                        $opt{oadc} = $opt{Msisdn} + ($n * $opt{Inc}) % $opt{Mod};
                    } else {
                        $opt{oadc} = $opt{Msisdn} + $n * $opt{Inc};
                    }
                }
            }
        }

        select(undef, undef, undef, $opt{Sleep}) if $opt{Sleep};

        $ucp->wait_all_trn;

        $elapsed = tv_interval ($t0) if $opt{Benchmark};

    }

    $ucp->join;

    show_stats;

    printf "%.2f\n", $elapsed - $is_authorized if $opt{Benchmark} and ($is_authorized and $opt{pwd} or not $is_authorized);

}

main;
