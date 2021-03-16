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

use lib '/usr/local/decor/core/lib';
use lib '/usr/local/decor/shared/lib';
use lib $ENV{ 'DECOR_ROOT' } . '/core/lib/';

use Time::HR;

use Data::Dumper;
use Decor::Core::Env; 
use Decor::Core::Describe; 
use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;


de_init( APP_NAME => 'app1' );

de_debug_inc();
my $root = de_root();

print "root is: $root\n";

my $tdes = describe_table( 'test1' );

my $rec = new Decor::Core::DB::Record;
$rec->create( 'TEST1' );

$rec->method( 'RECALC' );
