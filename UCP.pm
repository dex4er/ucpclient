package UCP;

use strict;
use warnings;

use POSIX;


our @ISA = qw(Exporter UCP::Base);

our @EXPORT    = qw();
our @EXPORT_OK = ();

our $VERSION = '0.01';


use constant STX               => "\002";
use constant ETX               => "\003";
use constant UCP_DELIMITER     => '/';
use constant DEFAULT_SMSC_PORT => 3024;
use constant ACK               => 'A';
use constant NACK              => 'N';
use constant OPERATION         => 'O';
use constant RESULT            => 'R';

use constant MSG_EOF           => '';

use constant IN                => '<<<';
use constant OUT               => '>>>';

use constant DEBUG_LEVEL       => 0;
use constant DEBUG_ID          => 0;


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    $self->SUPER::_init(@_);
    $self->{Trn}     = UCP::Trn->new();
    $self->{Timeout} = UCP::Timeout->new(@_);
    return $self;
}


sub make_message {
    my $self = shift;
    my %arg  = @_;

    my $op     = $arg{op};
    my $string = undef;

    if    ($op eq "01") { $string = $self->make_01(%arg) }
    elsif ($op eq "02") { $string = $self->make_02(%arg) }
    elsif ($op eq "03") { $string = $self->make_03(%arg) }
    elsif ($op eq "30") { $string = $self->make_30(%arg) }
    elsif ($op eq "31") { $string = $self->make_31(%arg) }
    elsif ($op eq "51") { $string = $self->make_51(%arg) }
    elsif ($op eq "52") { $string = $self->make_52(%arg) }
    elsif ($op eq "53") { $string = $self->make_53(%arg) }
    elsif ($op eq "54") { $string = $self->make_54(%arg) }
    elsif ($op eq "55") { $string = $self->make_55(%arg) }
    elsif ($op eq "56") { $string = $self->make_56(%arg) }
    elsif ($op eq "57") { $string = $self->make_57(%arg) }
    elsif ($op eq "58") { $string = $self->make_58(%arg) }
    elsif ($op eq "60") { $string = $self->make_60(%arg) }
    elsif ($op eq "61") { $string = $self->make_61(%arg) }

    return $string;
}


sub parse_message {
    my ($self, $resp) = @_;

    my $ref_mess = undef;

    if ($resp =~ m/^\d{2}\/\d{5}\/.\/01\/.*/) {
        $ref_mess = $self->parse_01($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/02\/.*/) {
        $ref_mess = $self->parse_02($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/03\/.*/) {
        $ref_mess = $self->parse_03($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/30\/.*/) {
        $ref_mess = $self->parse_30($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/31\/.*/) {
        $ref_mess = $self->parse_31($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/51\/.*/) {
        $ref_mess = $self->parse_51($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/52\/.*/) {
        $ref_mess = $self->parse_52($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/53\/.*/) {
        $ref_mess = $self->parse_53($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/54\/.*/) {
        $ref_mess = $self->parse_54($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/55\/.*/) {
        $ref_mess = $self->parse_55($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/56\/.*/) {
        $ref_mess = $self->parse_56($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/57\/.*/) {
        $ref_mess = $self->parse_57($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/58\/.*/) {
        $ref_mess = $self->parse_58($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/60\/.*/) {
        $ref_mess = $self->parse_60($resp);
    }
    elsif ($resp =~ m/^\d{2}\/\d{5}\/.\/61\/.*/) {
        $ref_mess = $self->parse_61($resp);
    }

    return $ref_mess;
}


sub parse_result_trn {
    my ($self, $resp) = @_;

    return unless defined $resp;

    if ($resp =~ m/^(\d{2})\/\d{5}\/R\/.*/) {
        return $1;
    }

    return;
}


sub is_operation_message {
    my ($self, $msg) = @_;
    return unless defined $msg;
    if (ref $msg eq 'HASH') {
        return $msg->{type} eq UCP::OPERATION if defined $msg->{type};
        return defined $msg->{operation};
    }
    return $msg =~ m/^(\d{2})\/\d{5}\/O\/.*/;
}


sub is_result_message {
    my ($self, $msg) = @_;
    return unless defined $msg;
    if (ref $msg eq 'HASH') {
        return $msg->{type} eq UCP::RESULT if defined $msg->{type};
        return defined $msg->{result};
    }
    return $msg =~ m/^(\d{2})\/\d{5}\/R\/.*/;
}


sub parse_01 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{adc}  = $ucp[4];
        $mess{oadc} = $ucp[5];
        $mess{ac}   = $ucp[6];
        $mess{mt}   = $ucp[7];
        $mess{nmsg} = (defined $mess{mt} and $mess{mt} eq '2') ? $ucp[8] : '';
        $mess{amsg} =
          (defined $mess{mt} and $mess{mt}) eq '3' ? $self->decode_ira($ucp[8]) : '';
        $mess{checksum} = $ucp[9];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{sm}       = $ucp[5];
            $mess{checksum} = $ucp[6];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub make_01 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $text =
          (defined $arg{nmsg} && !defined $arg{amsg})
          ? $arg{nmsg}
          : (defined $arg{amsg} ? $self->encode_ira($arg{amsg}) : '');

        my $string =
            (defined $arg{adc} ? $arg{adc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ac} ? $arg{ac} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{mt} ? $arg{mt} : '')
          . UCP::UCP_DELIMITER
          . $text;

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '01';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '01';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '01';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub parse_02 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{npl}  = $ucp[4];
        $mess{rads} = $ucp[5];
        $mess{oadc} = $ucp[6];
        $mess{ac}   = $ucp[7];
        $mess{mt}   = $ucp[8];
        $mess{nmsg} = (defined $mess{mt} and $mess{mt} eq '2') ? $ucp[9] : '';
        $mess{amsg} =
          (defined $mess{mt} and $mess{mt} eq '3') ? $self->decode_ira($ucp[9]) : '';
        $mess{checksum} = $ucp[10];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{sm}       = $ucp[5];
            $mess{checksum} = $ucp[6];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub make_02 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $text =
          (defined $arg{nmsg} && !defined $arg{amsg})
          ? $arg{nmsg}
          : $self->encode_ira($arg{amsg});

        my $string =
            (defined $arg{npl} ? $arg{npl} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{rads} ? $arg{rads} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ac} ? $arg{ac} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{mt} ? $arg{mt} : '')
          . UCP::UCP_DELIMITER
          . $text;

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '02';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '02';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '02';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub parse_03 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{rad}  = $ucp[4];
        $mess{oadc} = $ucp[5];
        $mess{ac}   = $ucp[6];
        $mess{npl}  = $ucp[7];                          #must be 0
        $mess{gas}  = $ucp[8];                          #empty if npl 0
        $mess{rp}   = $ucp[9];
        $mess{pr}   = $ucp[10];
        $mess{lpr}  = $ucp[11];
        $mess{ur}   = $ucp[12];
        $mess{lur}  = $ucp[13];
        $mess{rc}   = $ucp[14];
        $mess{lrc}  = $ucp[15];
        $mess{dd}   = $ucp[16];
        $mess{ddt}  = $ucp[17];
        $mess{mt}   = $ucp[18];
        $mess{nmsg} = (defined $mess{mt} and $mess{mt} eq '2') ? $ucp[19] : '';
        $mess{amsg} =
          (defined $mess{mt} and $mess{mt} eq '3') ? $self->decode_ira($ucp[19]) : '';
        $mess{checksum} = $ucp[20];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{sm}       = $ucp[5];
            $mess{checksum} = $ucp[6];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub make_03 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $text =
          (defined $arg{nmsg} && !defined $arg{amsg})
          ? $arg{nmsg}
          : $self->encode_ira($arg{amsg});

        my $string =
            (defined $arg{rad} ? $arg{rad} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ac} ? $arg{ac} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{npl} ? $arg{npl} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{gas} ? $arg{gas} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{rp} ? $arg{rp} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{pr} ? $arg{pr} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lpr} ? $arg{lpr} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ur} ? $arg{ur} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lur} ? $arg{lur} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{rc} ? $arg{rc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lrc} ? $arg{lrc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{dd} ? $arg{dd} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ddt} ? $arg{ddt} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{mt} ? $arg{mt} : '')
          . UCP::UCP_DELIMITER
          . $text;

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '03';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '03';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '03';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub parse_30 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{adc}      = $ucp[4];
        $mess{oadc}     = $ucp[5];
        $mess{ac}       = $ucp[6];
        $mess{nrq}      = $ucp[7];
        $mess{nad}      = $ucp[8];
        $mess{npid}     = $ucp[9];
        $mess{dd}       = $ucp[10];
        $mess{ddt}      = $ucp[11];
        $mess{vp}       = $ucp[12];
        $mess{amsg}     = $self->decode_ira($ucp[13]);
        $mess{checksum} = $ucp[14];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{mvp}      = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub make_30 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $text = $self->encode_ira($arg{amsg});

        my $string =
            (defined $arg{adc} ? $arg{adc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ac} ? $arg{ac} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{nrq} ? $arg{nrq} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{nad} ? $arg{nad} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{npid} ? $arg{npid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{dd} ? $arg{dd} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ddt} ? $arg{ddt} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{vp} ? $arg{vp} : '')
          . UCP::UCP_DELIMITER
          . $text;

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '30';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{mvp} ? $arg{mvp} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '30';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '30';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub parse_31 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{adc}      = $ucp[4];
        $mess{pid}      = $ucp[5];
        $mess{checksum} = $ucp[6];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{sm}       = $ucp[5];
            $mess{checksum} = $ucp[6];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub make_31 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $string =
            (defined $arg{adc} ? $arg{adc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{pid} ? $arg{pid} : '');

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '31';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '31';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '31';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub _parse_5x {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{adc}  = $ucp[4];
        $mess{otoa} = $ucp[32];
        $mess{oadc} =
          (defined $mess{otoa} and $mess{otoa} eq '5039')
          ? $self->decode_7bit($ucp[5])
          : $ucp[5];
        $mess{ac}    = $ucp[6];
        $mess{nrq}   = $ucp[7];
        $mess{nadc}  = $ucp[8];
        $mess{nt}    = $ucp[9];
        $mess{npid}  = $ucp[10];
        $mess{lrq}   = $ucp[11];
        $mess{lrad}  = $ucp[12];
        $mess{lpid}  = $ucp[13];
        $mess{dd}    = $ucp[14];
        $mess{ddt}   = $ucp[15];
        $mess{vp}    = $ucp[16];
        $mess{rpid}  = $ucp[17];
        $mess{scts}  = $ucp[18];
        $mess{dst}   = $ucp[19];
        $mess{rsn}   = $ucp[20];
        $mess{dscts} = $ucp[21];
        $mess{mt}    = $ucp[22];
        $mess{nb}    = $ucp[23];
        $mess{nmsg}  = $ucp[24] if defined $mess{mt} and $mess{mt} eq '2';
        $mess{amsg}  = $self->decode_ira($ucp[24])
          if defined $mess{mt} and $mess{mt} eq '3';
        $mess{tmsg}     = $ucp[24] if defined $mess{mt} and $mess{mt} eq '4';
        $mess{mms}      = $ucp[25];
        $mess{pr}       = $ucp[26];
        $mess{dcs}      = $ucp[27];
        $mess{mcls}     = $ucp[28];
        $mess{rpi}      = $ucp[29];
        $mess{cpg}      = $ucp[30];
        $mess{rply}     = $ucp[31];
        $mess{hplmn}    = $ucp[33];
        $mess{xser}     = $ucp[34];
        $mess{res4}     = $ucp[35];
        $mess{res5}     = $ucp[36];
        $mess{checksum} = $ucp[37];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{mvp}      = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;

}


sub _make_5x {
    my ($self)  = shift;
    my $arg     = shift;
    my $op_type = shift;

    my $message_string = undef;

    if (defined $arg->{operation} and $arg->{operation} == 1) {

        my $text = '';
        my $from = '';

        if (defined $arg->{amsg}) {
            $text = $self->encode_ira($arg->{amsg});
        }
        else {
            $text = defined $arg->{nmsg}
              && !defined $arg->{tmsg} ? $arg->{nmsg}
	      : (defined $arg->{tmsg} ? $arg->{tmsg} : '');
        }

        $from = defined $arg->{oadc} ? (
            (defined $arg->{otoa} and $arg->{otoa} eq '5039')
          ? $self->encode_7bit($arg->{oadc})
          : $arg->{oadc}) : '';

        my $string =
            (defined $arg->{adc} ? $arg->{adc} : '')
          . UCP::UCP_DELIMITER
          . $from
          . UCP::UCP_DELIMITER
          . (defined $arg->{ac} ? $arg->{ac} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{nrq} ? $arg->{nrq} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{nadc} ? $arg->{nadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{nt} ? $arg->{nt} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{npid} ? $arg->{npid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{lrq} ? $arg->{lrq} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{lrad} ? $arg->{lrad} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{lpid} ? $arg->{lpid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{dd} ? $arg->{dd} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{ddt} ? $arg->{ddt} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{vp} ? $arg->{vp} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{rpid} ? $arg->{rpid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{scts} ? $arg->{scts} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{dst} ? $arg->{dst} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{rsn} ? $arg->{rsn} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{dscts} ? $arg->{dscts} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{mt} ? $arg->{mt} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{nb} ? $arg->{nb} : '')
          . UCP::UCP_DELIMITER
          . $text
          . UCP::UCP_DELIMITER
          . (defined $arg->{mms} ? $arg->{mms} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{pr} ? $arg->{pr} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{dcs} ? $arg->{dcs} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{mcls} ? $arg->{mcls} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{rpi} ? $arg->{rpi} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{cpg} ? $arg->{cpg} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{rply} ? $arg->{rply} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{otoa} ? $arg->{otoa} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{hplmn} ? $arg->{hplmn} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{xser} ? $arg->{xser} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{res4} ? $arg->{res4} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg->{res5} ? $arg->{res5} : '');

        my $header =
            (defined $arg->{trn} ? $arg->{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER
          . $op_type;

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg->{result}) and $arg->{result} == 1) {

        if (defined $arg->{ack} and $arg->{ack} ne '') {

            my $string =
                $arg->{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg->{mvp} ? $arg->{mvp} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg->{sm} ? $arg->{sm} : '');

            my $header =
                sprintf("%02d", $arg->{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER
              . $op_type;

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg->{nack} and $arg->{nack} ne '') {

            my $string =
                $arg->{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg->{ec} ? $arg->{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg->{sm} ? ($arg->{sm} =~ /^ / ? $arg->{sm} : $self->encode_ira($arg->{sm})) : '');

            my $header =
                sprintf("%02d", $arg->{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER
              . $op_type;

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub parse_51 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_52 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_53 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_54 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_55 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_56 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_57 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub parse_58 {
    my ($self, $response) = @_;
    return $self->_parse_5x($response);
}


sub make_51 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '51');
}


sub make_52 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '52');
}


sub make_53 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '53');
}


sub make_54 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '54');
}


sub make_55 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '55');
}


sub make_56 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '56');
}


sub make_57 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '57');
}


sub make_58 {
    my ($self) = shift;
    my %arg = @_;
    return $self->_make_5x(\%arg, '58');
}


sub parse_60 {
    my ($self, $response) = @_;
    my %mess;

    my $resp_tmp = $response;
    $resp_tmp =~ s/..$//;
    $mess{my_checksum} = $self->checksum($resp_tmp);

    my (@ucp) = split(UCP::UCP_DELIMITER, $response);

    #header...
    $mess{trn}  = $ucp[0];
    $mess{len}  = $ucp[1];
    $mess{type} = $ucp[2];
    $mess{ot}   = $ucp[3];

    if ($mess{type} eq "O") {
        $mess{oadc}     = $ucp[4];
        $mess{oton}     = $ucp[5];
        $mess{onpi}     = $ucp[6];
        $mess{styp}     = $ucp[7];
        $mess{pwd}      = $self->decode_ira($ucp[8]);
        $mess{npwd}     = $self->decode_ira($ucp[9]);
        $mess{vers}     = $ucp[10];
        $mess{ladc}     = $ucp[11];
        $mess{lton}     = $ucp[12];
        $mess{lnpi}     = $ucp[13];
        $mess{opid}     = $ucp[14];
        $mess{res1}     = $ucp[15];
        $mess{checksum} = $ucp[37];
    }
    else {
        if ($ucp[4] eq UCP::ACK) {
            $mess{ack}      = $ucp[4];
            $mess{sm}       = $ucp[5];
            $mess{checksum} = $ucp[6];
        }
        else {
            $mess{nack}     = $ucp[4];
            $mess{ec}       = $ucp[5];
            $mess{sm}       = $ucp[6];
            $mess{checksum} = $ucp[7];
        }
    }

    return \%mess;
}


sub parse_61 {
    my ($self, $response) = @_;
    return $self->parse_60($response);
}


sub make_60 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $string =
            (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oton} ? $arg{oton} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{onpi} ? $arg{onpi} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{styp} ? $arg{styp} : '')
          . UCP::UCP_DELIMITER
          . (
            defined $arg{pwd} ? $self->encode_ira($arg{pwd})
            : ''
          )
          . UCP::UCP_DELIMITER
          . (
            defined $arg{npwd} ? $self->encode_ira($arg{npwd})
            : ''
          )
          . UCP::UCP_DELIMITER
          . (defined $arg{vers} ? $arg{vers} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ladc} ? $arg{ladc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lton} ? $arg{lton} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lnpi} ? $arg{lnpi} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{opid} ? $arg{opid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{res1} ? $arg{res1} : '');

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '60';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '60';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '60';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub make_61 {
    my ($self) = shift;
    my %arg = @_;

    my $message_string = undef;

    if (defined $arg{operation} and $arg{operation} == 1) {

        my $string =
            (defined $arg{oadc} ? $arg{oadc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{oton} ? $arg{oton} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{onpi} ? $arg{onpi} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{styp} ? $arg{styp} : '')
          . UCP::UCP_DELIMITER
          . (
            defined $arg{pwd} ? $self->encode_ira($arg{pwd})
            : ''
          )
          . UCP::UCP_DELIMITER
          . (
            defined $arg{npwd} ? $self->encode_ira($arg{npwd})
            : ''
          )
          . UCP::UCP_DELIMITER
          . (defined $arg{vers} ? $arg{vers} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{ladc} ? $arg{ladc} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lton} ? $arg{lton} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{lnpi} ? $arg{lnpi} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{opid} ? $arg{opid} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{res1} ? $arg{res1} : '')
          . UCP::UCP_DELIMITER
          . (defined $arg{res2} ? $arg{res2} : '');

        my $header =
            (defined $arg{trn} ? $arg{trn} : $self->{Trn}->next())
          . UCP::UCP_DELIMITER
          . $self->data_len($string)
          . UCP::UCP_DELIMITER . UCP::OPERATION
          . UCP::UCP_DELIMITER . '61';

        $message_string = $header
          . UCP::UCP_DELIMITER
          . $string
          . UCP::UCP_DELIMITER
          . $self->checksum($header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER);

    }
    elsif (exists($arg{result}) and $arg{result} == 1) {

        if (defined $arg{ack} and $arg{ack} ne '') {

            my $string =
                $arg{ack}
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '61';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);

        }
        elsif (defined $arg{nack} and $arg{nack} ne '') {

            my $string =
                $arg{nack}
              . UCP::UCP_DELIMITER
              . (defined $arg{ec} ? $arg{ec} : '')
              . UCP::UCP_DELIMITER
              . (defined $arg{sm} ? $arg{sm} : '');

            my $header =
                sprintf("%02d", $arg{trn})
              . UCP::UCP_DELIMITER
              . $self->data_len($string)
              . UCP::UCP_DELIMITER . UCP::RESULT
              . UCP::UCP_DELIMITER . '61';

            $message_string = $header
              . UCP::UCP_DELIMITER
              . $string
              . UCP::UCP_DELIMITER
              . $self->checksum($header
                  . UCP::UCP_DELIMITER
                  . $string
                  . UCP::UCP_DELIMITER);
        }
    }

    return $message_string;
}


sub dump_filter {
    my ($hash) = @_;
    return [ sort (grep {$hash->{$_} ne ''} keys %$hash) ];
}


sub make_scts {
    my ($self) = @_;
    return POSIX::strftime('%d%m%y%H%M%S', localtime);
}



package UCP::Base;
use strict;

use Encode;
use Data::Dumper;



our %ec_string = (
    ''   => 'Unknown error code',
    '01' => 'Checksum error',
    '02' => 'Syntax error',
    '04' => 'Operation not allowed (at this point in time)',
    '05' => 'Call barring active',
    '06' => 'AdC invalid',
    '07' => 'Authentication failure',
    '08' => 'Legitimisation code for all calls, failure',
    '24' => 'Message too long',
    '26' => 'Message type not valid for the pager type',
);


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    my %opt = @_;

    $self->{Debug}{id} = exists $opt{DebugId} ? $opt{DebugId} : UCP::DEBUG_ID;
    $self->{Debug}{level} = exists $opt{DebugLevel} ? $opt{DebugLevel} : UCP::DEBUG_LEVEL;

    return $self;
}


sub debug {
    my $self = shift;
    my %arg = (
        id => $self->{Debug}{id},
        function => '',
        direction => '***',
        msg => '',
        prefix => '',
        suffix => '',
        lf => 1,
        @_
    );
    $arg{msg} = '???' unless defined $arg{msg};
    printf STDERR "%s %s%s %s %s[%s]%s%s",
        scalar localtime,
        $arg{id}, $arg{function} ? ('('.$arg{function}.')') : '',
        $arg{direction}, $arg{prefix}, $arg{msg}, $arg{suffix},
        $arg{lf} ? "\n" : '';
    flush STDERR;
}


sub debug_lf {
    my $self = shift;
    my %arg = (
        lf => 1,
        @_
    );
    printf STDERR "%s\n",
        $arg{suffix},
        $arg{lf} ? "\n" : '';
    flush STDERR;
}


sub ec_string {
    my $self = shift;
    my $ec = shift || '';
    return $ec_string{$ec};
}


sub dump {
    my $self = shift;
    my $msg = shift || return;

    sub dump_filter {
        my ($hash) = @_;
        return [ sort (grep {defined $hash->{$_} and $hash->{$_} ne ''} keys %$hash) ];
    }

    my $dumper = Data::Dumper->new([ $msg ]);
    $dumper->Quotekeys(0)->Sortkeys(\&dump_filter)->Terse(1)->Useqq(1);

    my $dump = "\t" . $dumper->Dump;

    if (defined $msg->{ec}) {
        my $ec_string = $ec_string{exists $ec_string{$msg->{ec}} ? $msg->{ec} : ''};
        $dump =~ s[ec => "\d+",][$& /* $ec_string */];
    }

    return $dump;
}


# Calculate packet checksum
sub checksum {
    my $self = shift;
    my $checksum;
    defined($_[0]) || return (0);
    map { $checksum += ord } (split //, pop @_);
    sprintf("%02X", $checksum % 256);
}


# Calculate data length
sub data_len {
    my $self = shift;
    defined($_[0]) || return (0);
    my $len = length(pop @_) + 17;
    for (1 .. (5 - length($len))) {
        $len = '0' . $len;
    }
    $len;
}


sub convert_sms_to_ascii {
    my $self = shift;
    my $msg = shift;
    $msg = decode "GSM0338", $msg
        if defined $msg;
    return $msg;
}


sub convert_ascii_to_sms {
    my $self = shift;
    my $msg = shift;
    $msg = encode "GSM0338", $msg
        if defined $msg;
    return $msg;
}


sub decode_7bit {
    my $self = shift;
    my $msg = shift;

    return '' if not defined $msg or $msg eq '';
    return $msg if $msg =~ /[^0-9A-F]/i;

    $msg =~ s/^(..)//;
    my $len = (hex($1)+2)*4;

    my $bit = unpack("b*", pack("H*", $msg));
    $bit =~ s/(.{7})/$1./g;

    $bit = substr($bit, 0, $len);
    $bit = substr($bit, 0, int(length($bit)/8)*8);

    my $out = pack("b*", $bit);
    return $self->convert_sms_to_ascii($out);
}


sub encode_7bit {
    my $self = shift;
    my $msg = shift;
    return '' if not defined $msg or $msg eq '';

    $msg = $msg eq '@' ? "\x00" : $self->convert_ascii_to_sms($msg);

    my $len = length($msg) * 2;
    $len = $len - ($len > 6 ? int($len/8) : 0);

    my $bit = unpack("b*", $msg);
    $bit =~ s/(.{7})./$1/g;

    my $out = uc unpack("H*", pack("b*", $bit));
    return sprintf "%02X%s", $len, $out;
}


sub decode_ira {
    my $self = shift;
    my $msg = shift;
    return '' if not defined $msg or $msg eq '';

    if ($msg =~ /^ /) {
	return $msg;
    }
    my $out = pack "H*", $msg;
    return $self->convert_sms_to_ascii($out);
}


sub encode_ira {
    my $self = shift;
    my $msg = shift;
    return '' if not defined $msg or $msg eq '';

    my $out = uc unpack "H*", $self->convert_ascii_to_sms($msg);

    return $out;
}



package UCP::Trn;

use strict;


use constant HIGHEST_TRN => 99;


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    return $self;
}


sub current {
    my $self = shift;
    return $self->reset if not defined $self->{Trn};
    return sprintf "%02d", $self->{Trn};
}


sub next {
    my $self = shift;
    return $self->reset if not defined $self->{Trn};

    $self->{Trn}++;
    $self->{Trn} = 0 if ($self->{Trn} > HIGHEST_TRN);
    return sprintf "%02d", $self->{Trn};
}


sub reset {
    my $self = shift;
    $self->{Trn} = 0;
    return sprintf "%02d", $self->{Trn};
}


sub set {
    my $self = shift;
    $self->{Trn} = shift;
    $self->{Trn} = 0 if ($self->{Trn} > HIGHEST_TRN or $self->{Trn} < 0);
    return sprintf "%02d", $self->{Trn};
}



package UCP::Timeout;

use strict;


use constant MIN_TIMEOUT     => 0;    # No timeout at all!
use constant DEFAULT_TIMEOUT => 15;
use constant MAX_TIMEOUT     => 60;


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    my %opt = @_;

    $self->set($opt{Timeout});
    return $self;
}


sub set {
    my $self = shift;
    my $timeout = shift || DEFAULT_TIMEOUT;

    if ($timeout > MAX_TIMEOUT) {
        $timeout = MAX_TIMEOUT;
    }
    elsif ($timeout < MIN_TIMEOUT) {
        $timeout = MIN_TIMEOUT;
    }

    return $self->{timeout} = $timeout;
}


sub get {
    my $self = shift;
    return $self->{timeout};
}


package UCP::Socket;

use strict;
use Config;

use IO::Socket::INET;
use IO::Select;


BEGIN {
    if ($Config{useithreads}) {
	require threads;
	import threads;
    }
}


our @ISA = qw(UCP);


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    my %opt = @_;

    $self->SUPER::_init(%opt);

    $self->{Timeout} = UCP::Timeout->new(%opt);

    if (exists $opt{PeerAddr} or exists $opt{PeerHost} or
      exists $opt{LocalAddr} or exists $opt{LocalHost} or exists $opt{Listen}) {
        if (exists $opt{Listen}) {
            $self->{Listen} = 1;
            $opt{LocalAddr} = '127.0.0.1' if not exists $opt{LocalAddr} and not exists $opt{LocalHost};
            $opt{LocalPort} = UCP::DEFAULT_SMSC_PORT if not exists $opt{LocalPort};
            $opt{Timeout} = exists $opt{ListenTimeout} ? $opt{ListenTimeout} : undef;

            $SIG{CHLD} = 'IGNORE';
            $SIG{HUP} = 'IGNORE';
            $SIG{TERM} = sub { $self->debug(msg=>'SIGTERM') if $self->{Debug}{level} >= 2; };

            if (exists $opt{ServerModel} and $opt{ServerModel} eq 'threads') {
                $self->{Server}{model} = 'threads';
            }
            else {
                $self->{Server}{model} = 'fork';
            }

            $self->debug(msg=>sprintf('connection listen on %s:%s', $opt{LocalAddr} || $opt{LocalHost}, $opt{LocalPort})) if $self->{Debug}{level} >= 4;
        }
        else {
            $opt{PeerPort} = UCP::DEFAULT_SMSC_PORT if not exists $opt{PeerPort} and not exists $opt{Listen};
            $opt{Timeout} = $self->{Timeout}->get;
            $self->debug(msg=>sprintf('connection to %s:%s', $opt{PeerAddr} || $opt{PeerHost}, $opt{PeerPort})) if $self->{Debug}{level} >= 3;
        }
        $self->{Socket}{in} = IO::Socket::INET->new(%opt) or die "Can not create connection: $!";
        $self->{Socket}{out} = $self->{Socket}{in};
    }
    else {
        $self->debug(msg=>'connection on stdin/stdout') if $self->{Debug}{level} >= 4;
        $self->{Socket}{in} = IO::Socket::INET->new;
        $self->{Socket}{in}->fdopen(fileno(STDIN), '<');
        $self->{Socket}{in}->autoflush(1);
        $self->{Socket}{in}->blocking(exists $opt{Blocking} ? $opt{Blocking} : 1);
        $self->{Socket}{out} = IO::Socket::INET->new;
        $self->{Socket}{out}->fdopen(fileno(STDOUT), '>');
        $self->{Socket}{out}->autoflush(1);
        $self->{Socket}{out}->blocking(exists $opt{Blocking} ? $opt{Blocking} : 1);
    }
    $self->{Select}{in} = IO::Select->new;
    $self->{Select}{in}->add($self->{Socket}{in});
    $self->{Select}{out} = IO::Select->new;
    $self->{Select}{out}->add($self->{Socket}{out});

    return $self;
}


sub close {
    my $self = shift;
    if ($self->{Debug}{level} >= 3) {
        if ($self->{Listen}) {
            my $peer_host = $self->{Socket}{in}->peerhost();
            my $peer_port = $self->{Socket}{in}->peerport();
            $self->debug(msg=>sprintf('connection close for %s:%s', $peer_host, $peer_port));
        }
        else {
            $self->debug(msg=>'connection close');
        }
    }
    $self->{Socket}{in}->close;
    $self->{Socket}{out}->close;
    return;
}


# shutdown and close connection
sub shutdown {
    my $self = shift;
    if ($self->{Debug}{level} >= 4) {
        if ($self->{Listen}) {
            my $local_host = $self->{Socket}{in}->sockhost();
            my $local_port = $self->{Socket}{in}->sockport();
            $self->debug(msg=>sprintf('connection shutdown on %s:%s', $local_host, $local_port));
        }
        else {
            $self->debug(msg=>'connection shutdown');
        }
    }
    $self->{Socket}{in}->shutdown(2) if $self->{Socket}{in}->connected;
    $self->{Socket}{out}->shutdown(2) if $self->{Socket}{out}->connected;
    $self->{Socket}{in}->close;
    $self->{Socket}{out}->close;
    return;
}


# spawn new 
sub _new_connection {
    my $self = shift;
    my $socket = shift;
    my $hook = shift;
    my @args = @_;

    if ($socket) {
        if ($self->{Debug}{level} >= 3) {
            my $peer_host = $socket->peerhost();
            my $peer_port = $socket->peerport();
            $self->debug(msg=>sprintf('new connection from %s:%s', $peer_host, $peer_port));
        }

        $self->{Socket}{in}->close;
        $self->{Socket}{in} = $socket;
        $self->{Socket}{out} = $self->{Socket}{in};

        $self->{Select}{in} = IO::Select->new;
        $self->{Select}{in}->add($self->{Socket}{in});
        $self->{Select}{out} = IO::Select->new;
        $self->{Select}{out}->add($self->{Socket}{out});
    }

    &$hook(@args) if $hook;

    if ($socket) {
        $self->close;
    }
}


# accept new connection and call sub
# return undef if no new connection, 0 at the end of new process/thread
sub accept {
    my $self = shift;
    my $hook = shift;
    my @args = @_;

    if ($self->{Listen}) {

        if ($self->{Debug}{level} >= 4) {
            my $local_host = $self->{Socket}{in}->sockhost();
            my $local_port = $self->{Socket}{in}->sockport();
            $self->debug(msg=>sprintf('connection wait on %s:%s', $local_host, $local_port));
        }
        my $socket = $self->{Socket}{in}->accept;
        return unless $socket;

        if ($self->{Server}{model} eq 'threads') {
            my $thread = threads->create(\&_new_connection, $self, $socket, $hook, @args);
            die unless defined $thread;
            $thread->detach;
            return $thread;
        }
        else {
            my $pid = fork;
            die unless defined $pid;
            return $pid if $pid;
            $self->_new_connection($socket, $hook, @args);
        }

        return 0;
    }
    else {
        $self->_new_connection(undef, $hook, @args);
    }

    return;
}


sub send {
    my $self = shift;
    my $msg = shift;
    $self->debug(direction=>UCP::OUT, msg=>$msg, lf=>0) if $self->{Debug}{level} >= 2;
    my $ret = $self->write(UCP::STX.$msg.UCP::ETX);
    $self->debug_lf(suffix=>defined $ret?'':'!') if $self->{Debug}{level} >= 2;
    return $ret;
}


# returns empty string if eof and undef if no data
sub recv {
    my $self = shift;
    my ($msg, $c);

#    eval {
#        local $SIG{ALRM} = sub { die "TIMEOUT" };
#        alarm $self->{Timeout}->get;
        do {
            $c = $self->getc;
            return unless defined $c;
            return UCP::MSG_EOF if $c eq '';
        } until ($c eq UCP::STX);
        $c = '';
        do {
            $msg .= $c;
            $c = $self->getc;
            return unless defined $c;
            return UCP::MSG_EOF if $c eq '';
        } until ($c eq UCP::ETX);
#        alarm 0;
#    };
#    return if not defined $c;
    return if $c ne UCP::ETX;
#    return if $@ =~ /TIMEOUT/;
    $self->debug(direction=>UCP::IN, msg=>$msg) if $self->{Debug}{level} >= 2;
    return $msg;
}


sub write {
    my $self = shift;
    my $msg = shift;
    my %opt = @_;

    my $timeout = exists $opt{Timeout} ? UCP::Timeout->new(Timeout=>$opt{Timeout}) : $self->{Timeout};
    return unless $self->{Select}{out}->can_write($timeout->get);
    return $self->{Socket}{out}->write($msg);
}


# returns empty string if eol and undef if no data
sub getc {
    my $self = shift;
    my %opt = @_;

    my $c;
    my $timeout = exists $opt{Timeout} ? UCP::Timeout->new(Timeout=>$opt{Timeout}) : $self->{Timeout};

    #return if $self->{Socket}{in}->eof;
    return unless $self->{Select}{in}->can_read($timeout->get);
    my $ret = $self->{Socket}{in}->sysread($c, 1);
    return unless defined $ret;
    return '' unless $ret;
    return $c;
}



package UCP::Manager;

use strict;
use Config;


BEGIN {
    if ($Config{useithreads}) {
	require threads;
	import  threads;

	require threads::shared;
	import  threads::shared;

	require Thread::Queue;
	import  Thread::Queue;
	require Thread::Semaphore;
	import  Thread::Semaphore;
    }
}


our @ISA = qw(UCP::Socket);


use constant DEFAULT_WINDOW => 1;
use constant MSG_STOP       => 'MSG_STOP';


sub new { bless({}, shift())->_init(@_); }


sub _init {
    my $self = shift;
    my %opt = @_;

    if (not $Config{useithreads}) {
	require threads;
    }

    $self->SUPER::_init(%opt);

    my $trn = UCP::Trn->new;

    # window size
    $self->{Window} = $trn->set((exists $opt{Window} ? $opt{Window} : DEFAULT_WINDOW) - 1) + 1;

    # hooks
    $self->{Hook}{sender} = $opt{SenderHook};
    $self->{Hook}{receiver} = $opt{ReceiverHook};
    $self->{Hook}{parser} = $opt{ParserHook};

    # shared variables

    # TRN's for session management
    $self->{Session}{Trn} = &share([]);
    # free slots counter
    share($self->{Session}{Free});
    # debug id and level
    share($self->{Debug}{id});
    share($self->{Debug}{level});
    # shutdown phase
    share($self->{Shutdown});

    # initial value for free slots counter
    $self->{Session}{Free} = $self->{Window};
    # timeout for session
    $self->{Session}{Timeout} = $self->{Timeout}->set($opt{SessionTimeout});
    # TRN's timestamps for session timeouter, undef means empty slot
    $self->{Session}{Trn} = &share([]);
    foreach (0 .. ($self->{Window}-1)) {
        $self->{Session}{Trn}[$_] = undef;
    }

    return $self;
}


# create threads
sub create {
    my $self = shift;

    $self->{Queue}{sender} = Thread::Queue->new;
    $self->{Queue}{receiver} = Thread::Queue->new;
    $self->{Queue}{receiver_shutdown} = Thread::Queue->new;
    $self->{Queue}{timeouter_shutdown} = Thread::Queue->new;

    $self->{Thread}{sender} = threads->new(\&sender, $self);
    $self->{Thread}{receiver} = threads->new(\&receiver, $self);
    $self->{Thread}{parser} = threads->new(\&parser, $self);
    $self->{Thread}{timeouter} = threads->new(\&timeouter, $self);
    return;
}


# reserve TRN slot
sub reserve_trn {
    my $self = shift;

    my $i;
    LOCK: {
        lock($self->{Session}{Trn});
        for ($i = 0; $i < $self->{Window}; $i++) {
            if (not defined $self->{Session}{Trn}[$i]) {
                $self->{Session}{Trn}[$i] = time;
                last LOCK;
            }
        }
        # no free slots
        return;
    };

    LOCK: {
        lock($self->{Session}{Free});
        $self->{Session}{Free}--;
    }

    return $self->{Trn}->set($i);
}


# free TRN slot
sub free_trn {
    my $self = shift;
    my $trn = shift;

    return unless defined $trn;

    LOCK: {
        lock($self->{Session}{Trn});
        return unless defined $self->{Session}{Trn}[$trn];
        $self->{Session}{Trn}[$trn] = undef;
    }

    LOCK: {
        lock($self->{Session}{Free});
        $self->{Session}{Free}++;
    }

    UNLOCK: {
        no warnings 'threads';
        cond_broadcast($self->{Session}{Free});
    }

    return $trn;
}


# wait until free slots are available
sub wait_trn {
    my $self = shift;
    my $minimum = shift || 1;
    my %opt = @_;

    lock($self->{Session}{Free});
#use Data::Dumper; print STDERR Dumper 'wait_trn', $self->{Session}{Free};
    while ($self->{Session}{Free} < $minimum) {
        if (exists $opt{Timeout}) {
            for (my $i = 0; $i < $opt{Timeout}; $i++) {
                return if $self->{Shutdown};
                return 1 if cond_timedwait($self->{Session}{Free}, time() +
                    ($i+1 <= $opt{Timeout} ? 1 : $opt{Timeout} - $i));
            }
        }
        else {
            do {
#use Data::Dumper; print STDERR Dumper 'wait_trn', $self->{Session}{Free};
                return if $self->{Shutdown};
            } until cond_timedwait($self->{Session}{Free}, time() + 1);
        }
    }
    return 1;
}


# wait until one slot is available
sub wait_free_trn {
    my $self = shift;
    return $self->wait_trn(1, @_);
}


# wait until all slots are available
sub wait_all_trn {
    my $self = shift;
    return $self->wait_trn($self->{Window}, @_);
}


# reserve TRN session slot and make message
# undef means can not find free slot
sub make_message {
    my $self = shift;
    my %msg  = @_;

#use Data::Dumper; print STDERR Dumper \%msg;
    if ($self->is_operation_message(\%msg)) {
        return unless $msg{trn} = $self->reserve_trn;
    }
    return $self->SUPER::make_message(%msg);
}


# send message to sender queue
# undef means no sender thread (eof or shutdown)
sub send {
    my $self = shift;
    my $msg = shift;
    $self->debug(function=>'send', direction=>UCP::OUT, msg=>$msg) if $self->{Debug}{level} >= 6;

    return unless defined $msg;
    $self->{Queue}{sender}->enqueue($msg);
    return length($msg);
}


# receive message from receiver queue
# free TRN slot
# undef means no new message
sub recv {
    my $self = shift;
    my $msg = $self->{Queue}{receiver}->dequeue;
    $self->debug(function=>'recv', direction=>UCP::IN, msg=>$msg) if $self->{Debug}{level} >= 6;
    return if defined $msg and $msg eq MSG_STOP;

    my $trn = $self->parse_result_trn($msg);
    $self->free_trn($self->parse_result_trn($msg)) if $self->is_result_message($msg);
    return $msg;
}


# thread for sender from queue to socket
sub sender {
    my $self = shift;
    for (;;) {
        my $msg = $self->{Queue}{sender}->dequeue;
        $msg = &{$self->{Hook}{sender}}($self, $msg) if defined $msg and defined $self->{Hook}{sender};
        $msg = MSG_STOP if not defined $msg;
        $self->debug(function=>'sender', direction=>UCP::OUT, msg=>$msg) if $self->{Debug}{level} >= 5;
        if ($msg eq MSG_STOP) {
            $self->{Queue}{receiver}->enqueue($msg);
            return;
        }
        my $ret = $self->SUPER::send($msg);
        return unless $ret;
    }

}


# thread for receiver from socket to queue
sub receiver {
    my $self = shift;
    for (;;) {
        # requires another queue for ending signal
        return if defined $self->{Queue}{receiver_shutdown}->dequeue_nb;
        my $msg = $self->SUPER::recv;
        next unless defined $msg;
        $self->debug(function=>'receiver', direction=>UCP::IN, msg=>$msg) if $self->{Debug}{level} >= 5;
#use Data::Dumper; print STDERR Dumper 'receiver', $msg;
        $msg = &{$self->{Hook}{receiver}}($self, $msg) if defined $msg and defined $self->{Hook}{receiver};
        return $self->shutdown if $msg eq UCP::MSG_EOF;

        $self->{Queue}{receiver}->enqueue($msg);
    }
}


# thread for parser which reads and parses messages from receiver queue
sub parser {
    my $self = shift;
    for (;;) {
        my $msg = $self->recv;
        $self->debug(function=>'parser', direction=>UCP::IN, msg=>$msg) if $self->{Debug}{level} >= 5;
        $msg = &{$self->{Hook}{parser}}($self, $msg) if defined $msg and defined $self->{Hook}{parser};
        return unless defined $msg;
    }
}


# thread for timeouting sessions
sub timeouter {
    my $self = shift;
    for (;;) {
        # requires another queue for ending signal
        return if defined $self->{Queue}{timeouter_shutdown}->dequeue_nb;

        my $i;
        LOCK: {
            lock($self->{Session}{Trn});
            for ($i = 0; $i < $self->{Window}; $i++) {
                if (defined $self->{Session}{Trn}[$i]) {
                    if ($self->{Session}{Trn}[$i] + $self->{Session}{Timeout} <= time) {
                        $self->{Session}{Trn}[$i] = undef;

                        lock($self->{Session}{Free});
                        $self->{Session}{Free}++;

                        no warnings 'threads';
                        cond_broadcast($self->{Session}{Free});
                    }
                }
            }
        };

        # sleep 1
        select(undef, undef, undef, 1);
    }
}


# send signals to each queues
sub shutdown {
    my $self = shift;

    $self->{Shutdown} = 1;

    $self->SUPER::shutdown;

    $self->{Queue}{receiver_shutdown}->enqueue(MSG_STOP);
    $self->{Queue}{timeouter_shutdown}->enqueue(MSG_STOP);
    $self->{Queue}{sender}->enqueue(MSG_STOP);
    $self->{Queue}{receiver}->enqueue(MSG_STOP);
    return;
}


# join the threads
sub join {
    my $self = shift;

    $self->shutdown unless $self->{Shutdown};

    $self->{Thread}{timeouter}->join;
    $self->{Thread}{parser}->join;
    $self->{Thread}{sender}->join;
    $self->{Thread}{receiver}->join;
    return;
}
