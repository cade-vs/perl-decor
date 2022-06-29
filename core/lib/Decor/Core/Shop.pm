##############################################################################
##
##  Decor application machinery core
##  2014-2022 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Shop;
use strict;

use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                record_create
                record_load
                record_new
                io_new

                );

sub record_create
{
  my $new_rec = new Decor::Core::DB::Record;
  $new_rec->create( @_ );
  return $new_rec;
}

sub record_load
{
  my $new_rec = new Decor::Core::DB::Record;
  $new_rec->load( @_ ) or return undef;
  return $new_rec;
}

sub record_new
{
  return new Decor::Core::DB::Record;
}

sub io_new
{
  return new Decor::Core::DB::IO;
}

### EOF ######################################################################
1;
