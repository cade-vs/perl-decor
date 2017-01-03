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
use lib '/usr/local/decor/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Tools;
use App::Recoil::Env;
use App::Recoil::Files;
use App::Recoil::Protocols;
use Data::Dumper;

$RED_APP_NAME = 'app1';
$RED_DEBUG    = 1;

#my @zz = grep { -e } glob_tree( "/usr/local/recoil/try.def" );
#print STDERR "zz(@zz)\n\n\n";

red_exec_protocol( 'try' );
red_exec_protocol( 'try' );


