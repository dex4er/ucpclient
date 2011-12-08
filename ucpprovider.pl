#!/usr/bin/perl

use strict;
use UCP;


use constant DEFAULT_ADC  => 500000;
use constant DEFAULT_OADC => 560;
use constant DEFAULT_AMSG => 'TestMe';


our %whitelist = (
    '509544549' => 1,
    '511334000' => 1,
    '512076259' => 1,
    '504000028' => 1,
    '501600112' => 1,
    '509312723' => 1,
    '501200953' => 1,
);


our %opt = ();
while (@ARGV) {
    if ($ARGV[0] =~ m/^(.*)=(.*)$/) {
        $opt{$1} = $2;
        shift;
    }
}


our $shutdown = 0;
our $pid = $$;


$opt{Delay} = 1 unless exists $opt{Delay};
$opt{Sleep} = 1 unless exists $opt{Sleep};

$opt{ParserHook} = \&parser_hook;
$opt{SenderHook} = \&sender_hook;
$opt{ReceiverHook} = \&receiver_hook;

$opt{DebugLevel} = 2 unless exists $opt{DebugLevel};
$opt{DebugId} = 'C' unless exists $opt{DebugId};

my $ucp = UCP::Manager->new(%opt) or die;




sub o_51 {
    my $ref_msg = shift;
    return $ucp->make_message(
        op        => 51,
        operation => 1,
        adc       => $ref_msg->{oadc},
        amsg      => $ref_msg->{amsg},
        mt        => 3,
        oadc      => $ref_msg->{adc},
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


sub r_xx_n_02 {
    my $ref_msg = shift;
    return $ucp->make_message(
            op => $ref_msg->{ot},
            result => 1,
            trn => $ref_msg->{trn},
            nack => UCP::NACK,
            ec => '02',
            sm => $ucp->ec_string('02'),
    );
}


my %counter : shared = ();


sub sender_hook {
    my $self = shift;
    my $msg = shift;
    $counter{o_51}++ if $self->is_operation_message($msg);
    return $msg;
}


sub parser_hook {
    my $self = shift;
    my $msg = shift;
    my $ref_msg = $self->parse_message($msg);

    if ($self->is_operation_message($ref_msg)) {
        $counter{o}++;
        if ($ref_msg->{ot} eq '52') {
            $self->send(r_xx_a($ref_msg));
            if ($whitelist{$ref_msg->{oadc}}) {
                $self->send(o_51($ref_msg));
            }
        }
        else {
            $self->send(r_xx_n_02($ref_msg));
            $counter{unknown}++;
        }
    } else {
        $counter{r}++;
        if ($ref_msg->{ot} eq '51') {
            $counter{r_51_ack}++;
        }
        else {
            $counter{unknown}++;
        }
    }
    return $msg;
}


sub receiver_hook {
    my $self = shift;
    my $msg = shift;
    #return 'dupa' if $msg =~ /^06/;
    return $msg;
}


sub show_stats {
    $ucp->debug(msg=>sprintf('%d msgs sent, %d msgs received, %d msgs responsed, %d msgs ack, %d msgs unknown',
        $counter{o_51}, $counter{o}, $counter{r}, $counter{r_51_ack}, $counter{unknown}));
}


sub SIGUSR1_handler {
    show_stats;
    $SIG{USR1} = \&SIGUSR1_handler;
}
$SIG{USR1} = \&SIGUSR1_handler;


sub SIGTERM_handler {
    $ucp->shutdown;
    $SIG{TERM} = \&SIGTERM_handler;
}
$SIG{TERM} = \&SIGTERM_handler;


sub SIGINT_handler {
    $ucp->shutdown;
    $SIG{INT} = sub { kill 9, $pid; };
}
$SIG{INT} = \&SIGINT_handler;


sub main {
    $ucp->create;

    until ($ucp->{Shutdown}) {
        select(undef, undef, undef, $opt{Delay}) if $opt{Delay};
    }

    select(undef, undef, undef, $opt{Sleep}) if $opt{Sleep};

    show_stats;

    $ucp->join;
}

main;
