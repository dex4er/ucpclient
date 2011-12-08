#!/usr/bin/perl -pl

# Decode ESTI GSM 03.38 IRA string to UTF-8

use Encode;

$_ = encode "UTF-8", decode "GSM0338", pack "H*", $_;
