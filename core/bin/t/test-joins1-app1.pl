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
use lib '/usr/local/decor/core/lib';
use lib '/usr/local/decor/shared/lib';
use lib $FindBin::Bin . "/../../lib";

use Time::HR;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );

my $db = new Decor::Core::DB::IO;

$db->select( 'TEST1', 'REF.NAME,REF2.NAME,REF2.REF3.NAME' );
