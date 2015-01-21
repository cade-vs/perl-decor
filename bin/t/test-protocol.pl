#!/usr/bin/perl
##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use FindBin;
use lib '/usr/local/recoil/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Tools;
use App::Recoil::Env;
use App::Recoil::FileDiscovery;
use App::Recoil::Protocols;
use Data::Dumper;

$RED_APP_NAME = 'app1';
$RED_DEBUG    = 1;

#my @zz = grep { -e } glob_tree( "/usr/local/recoil/try.def" );
#print STDERR "zz(@zz)\n\n\n";

red_exec_protocol( 'try' );
red_exec_protocol( 'try' );


