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
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;
use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $rio = new Decor::Core::DB::Record;

print Dumper( $rio );

$rio->create( 'test1' );

$rio->write( NAME => 'test name 115', SUMA => rand(), 'REF.NAME' => 'ref' . rand() );
print Dumper( $rio );

$rio->save();

$rio->write( NAME => 'test name 116' );
print Dumper( $rio );

$rio->save();
print Dumper( $rio );
