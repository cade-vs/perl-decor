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
use Decor::Core::DB::Record;

use Storable qw( nfreeze thaw );
use Compress::Zlib;
use MIME::Base64;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );

print STDERR '='x80;


my $rec = new Decor::Core::DB::Record;

$rec->load( 'DE_USERS', 1 );

my $printable_stored_data = ref_freeze_z( $rec );

my $rec_new = ref_thaw_z( $printable_stored_data );

print Dumper( $rec_new );


##############################################################################

sub ref_freeze_z
{
  my $ref = shift;

  ref( $ref ) ne '' or die "ref_freeze_z(): data reference required!\n";

  my $fz = encode_base64( Compress::Zlib::memGzip( nfreeze( $ref ) ), '' );
};

sub ref_thaw_z
{
  my $fz = shift;

  my ( $ref ) = thaw( Compress::Zlib::memGunzip( decode_base64( $fz ) ) );

  return ref( $ref ) ? $ref : undef;
};

##############################################################################
