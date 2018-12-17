#!/usr/bin/perl -p
##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
#[Sun Dec 03 03:42:42 2018] [error] [client 127.0.0.1]
INIT { $|++; }
s/^\[.+?\] \[.+?\] \[.+?\] (\[.+?\] )?(\w\w\d{5}: )?//;
s/,\s*referer:.+//;
s/\\x([0-9A-F][0-9A-F])/chr(hex($1))/gie;

