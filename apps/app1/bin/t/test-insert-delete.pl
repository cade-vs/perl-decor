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

use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );

use Time::HR;

use Data::Dumper;
use Decor::Core::Log;
use Decor::Core::Env;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

srand();

de_init( APP_NAME => 'app1' );
de_debug_inc();
de_debug_inc();
$DE_LOG_TO_STDERR = 1;
$DE_LOG_TO_FILES  = 1;

my $rec = new Decor::Core::DB::Record;

my $profile = new Decor::Core::Profile;
print "add groups [111]\n";
$profile->set_groups( qw( 100 ), 33..44 );
print "add groups [222]\n";
$rec->set_profile( $profile );
$rec->taint_mode_enable_all();

$rec->create( 'test1' );
$rec->write( 'NAME' => 'FOR DELETE: ' . rand(), 'AMOUNT3' => rand(), 'AMOUNT4' => rand(), 'SUMA' => rand(), 'CTIME' => time() );
$rec->save();

$rec->delete();
