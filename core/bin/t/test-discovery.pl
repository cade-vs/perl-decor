#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use FindBin;
use lib '/usr/local/recoil/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Dumper;
use App::Recoil::Env;
use App::Recoil::FileDiscovery;
use App::Recoil::Protocols;

$RED_APP_NAME = 'app1';
red_file_find_rescan();

print STDERR Dumper( \%App::Recoil::FileDiscovery::RED_FILE_DISCOVERY_CACHE, [ red_file_find_modules_list() ] );

red_file_find( 'try.proto.def', 'app', 'modules::', '::' );

red_exec_protocol( 'try' );


