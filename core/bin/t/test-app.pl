#!/usr/bin/perl
##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use lib '/usr/local/decor/core/lib';
use lib $ENV{ 'DECOR_ROOT' } . '/core/lib/';

use Time::HR;

use Data::Dumper;
use Decor::Core::Env; 
use Decor::Core::Describe; 

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;


de_init( APP_NAME => 'app1' );

de_debug_inc();
my $root = de_root();

print "root is: $root\n";

my $tdes = describe_table( 'test1' );

print Dumper( "table [test1] description", $tdes );
