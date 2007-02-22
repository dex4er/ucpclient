#!/usr/bin/perl

use Test;

BEGIN { plan tests => 13 }

use UCP;

ok(1);

ok(UCP->encode_7bit(''), '00');
ok(UCP->encode_7bit('@'), '0200');
ok(UCP->encode_7bit('1'), '0231');
ok(UCP->encode_7bit('12'), '043119');
ok(UCP->encode_7bit('123'), '0631D90C');
ok(UCP->encode_7bit('1234'), '0731D98C06');
ok(UCP->encode_7bit('12345'), '0931D98C5603');
ok(UCP->encode_7bit('123456'), '0B31D98C56B301');
ok(UCP->encode_7bit('1234567'), '0D31D98C56B3DD00');
ok(UCP->encode_7bit('12345678'), '0E31D98C56B3DD70');
ok(UCP->encode_7bit('123456789'), '1031D98C56B3DD7039');
ok(UCP->encode_7bit('123456789A'), '1231D98C56B3DD70B920');
ok(UCP->encode_7bit('123456789AB'), '1431D98C56B3DD70B9A010');
ok(UCP->encode_7bit('ALPHA@NUM'), '10412614190438AB4D');
