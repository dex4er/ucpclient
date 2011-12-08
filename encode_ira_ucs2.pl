#!/usr/bin/perl -pl

# Encode UTF-8 as UCS2-LE IRA string

use Encode;

$_ = uc unpack "H*", pack "n*", unpack "v*", encode "UCS-2LE", decode "UTF-8", $_;
