#!/usr/bin/perl -pl

use Encode;

s/^(..)//;
$l = (hex($1)+2)*4;
$b = unpack "b*", pack "H*", $_;
$b =~s /(.{7})/$1./g;
$b = substr $b, 0, $l;
$b = substr $b, 0, int(length($b)/8)*8;
$_ = decode "GSM0338", pack "b*", $b;
