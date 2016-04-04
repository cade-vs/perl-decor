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
use lib ( $ENV{ 'DECOR_ROOT' } || '/usr/local/decor' ) . "/core/lib";

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
de_debug_set( 11 );

my $dio = new Decor::Core::DB::IO;

$dio->insert( 'test2', { NAME => 'Testing ' . rand(), CNT => int(rand()), } );

$dio->select( 'test2' );
while( my $hr = $dio->fetch() )
{
  print Dumper( $hr );
}
