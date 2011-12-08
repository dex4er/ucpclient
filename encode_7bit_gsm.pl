#!/usr/bin/perl -pl

use Encode;

$_ = encode 'GSM0338', decode 'UTF-8', $_;
$l = length($_) * 2;
$l -= $l > 6 ? int $l / 8 : 0;
$b = unpack 'b*', $_;
$b =~ s/(.{7})./$1/g;
$_ = sprintf '%02X%s', $l, uc unpack 'H*', pack 'b*', $b;
