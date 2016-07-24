#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
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

my $res = $dio->update( 'test1', { suma => 999 }, 'REF = ?', { BIND => [ 77 ] } );

print "update res [$res]\n";

my $profile = new Decor::Core::Profile;
$profile->set_groups( qw( oper ) );
$dio->set_profile( $profile );
$dio->taint_mode_enable_all();

print Dumper( $dio->read_first1_hashref( 'test1', '.REF.CNT = ?', { BIND => [ 77 ] } ) );


my $dd = describe_table( 'test2' );
print Dumper( $dd );
