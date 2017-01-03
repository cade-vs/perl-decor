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
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;
$Data::Dumper::Indent   = 2;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $dio = new Decor::Core::DB::IO;

my $profile = new Decor::Core::Profile;
print "add groups [111]\n";
$profile->set_groups( qw( 900 ), 33..44 );
print "add groups [222]\n";
$dio->set_profile( $profile );
$dio->taint_mode_enable_all();


#my $t = gethrtime();
#for( 1..1000000 )
#{
#my $str = $profile->get_groups_string();
#}
#$t = ( gethrtime() - $t ) / 1_000_000_000;
#print "$t secs\n";
#die;

my $new_id = $dio->insert( 'test2', { NAME => 'Testing ' . rand(), CNT => int(rand()), } );
$dio->update_id( 'test2', { NAME => 'Testing ' . rand(), CNT => int(rand()), }, $new_id );

$dio->select( 'test1', 'NAME,REF.CNT' );
while( my $hr = $dio->fetch() )
{
  print Dumper( $hr );
}

die;

my $res = $dio->update( 'test1', { suma => 999 }, 'REF = ?', { BIND => [ 77 ] } );

print "update res [$res]\n";

my $profile = new Decor::Core::Profile;
$profile->set_groups( qw( oper ) );
$dio->set_profile( $profile );
$dio->taint_mode_enable_all();

print Dumper( $dio->read_first1_hashref( 'test1', '.REF.CNT = ?', { BIND => [ 77 ] } ) );


my $dd = describe_table( 'test2' );
print Dumper( $dd );
