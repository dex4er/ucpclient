#!/usr/bin/perl -pl

# Decode UCS2-LE IRA string to UTF-8

use Encode;

$_ = encode "UTF-8", decode "UCS-2LE", pack "v*", unpack "n*", pack "H*", $_;
