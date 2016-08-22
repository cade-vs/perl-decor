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

use FindBin;
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../../lib";

use Time::HR;

use Data::Dumper;
use Data::Tools;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Profile;
use Decor::Core::Describe;

use Storable qw( nfreeze thaw dclone );
use BSON;
use JSON;
use Data::Stacker;
use Data::MessagePack;
use XML::Bare;
use Sereal;

use Time::Profiler;  

my $pr = new Time::Profiler;
my $mp = Data::MessagePack->new();
my $xml = new XML::Bare( text => '<xml>', );

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );

my $tables_list = des_get_tables_list();
my $des = describe_table( 'test1' );

$des = { %$des };
hash_unlock_recursive( $des );

print STDERR Dumper( $des );

my ( $p, $j, $b, $a, $x, $s, $e );

{ my $_ps = $pr->begin_scope( 'P' ); $p = Storable::nfreeze( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'J' ); $j = JSON::encode_json( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'B' ); $b = BSON::encode( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'A' ); $a = $mp->pack( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'X' ); $x = $xml->xml( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'S' ); $s = stack_data( $des ) for 1..1000; }
{ my $_ps = $pr->begin_scope( 'E' ); $e = sereal_encode( $des ) for 1..1000; }

print "perl " . length( $p ) . "\n";
print "json " . length( $j ) . "\n";
print "bson " . length( $b ) . "\n";
print "mpck " . length( $a ) . "\n";
print "xmlx " . length( $x ) . "\n";
print "stck " . length( $s ) . "\n";
print "serl " . length( $e ) . "\n";

print $pr->report();
