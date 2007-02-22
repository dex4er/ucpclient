#!/usr/bin/perl

use Test;

BEGIN { plan tests => 13 }

use UCP;

ok(1);

ok(UCP->decode_7bit('00'), '');
ok(UCP->decode_7bit('0200'), '@');
ok(UCP->decode_7bit('0231'), '1');
ok(UCP->decode_7bit('043119'), '12');
ok(UCP->decode_7bit('0631D90C'), '123');
ok(UCP->decode_7bit('0731D98C06'), '1234');
ok(UCP->decode_7bit('0931D98C5603'), '12345');
ok(UCP->decode_7bit('0B31D98C56B301'), '123456');
ok(UCP->decode_7bit('0D31D98C56B3DD00'), '1234567');
ok(UCP->decode_7bit('0E31D98C56B3DD70'), '12345678');
ok(UCP->decode_7bit('1031D98C56B3DD7039'), '123456789');
ok(UCP->decode_7bit('1231D98C56B3DD70B920'), '123456789A');
ok(UCP->decode_7bit('1431D98C56B3DD70B9A010'), '123456789AB');
ok(UCP->decode_7bit('10412614190438AB4D'), 'ALPHA@NUM');
