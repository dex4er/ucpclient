#!/usr/bin/perl -pl

# Encode UTF-8 as ESTI GSM 03.38 IRA string

use Encode;

$_ = uc unpack "H*", encode "GSM0338", decode "UTF-8", $_;
