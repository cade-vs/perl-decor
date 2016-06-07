##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record;
use strict;

use parent 'Decor::Core::DB';
use Exception::Sink;

use Decor::Core::Utils;

##############################################################################

sub __init
{
  my $self = shift;
  
  1;
}

sub reset
{
  my $self = shift;
  
  %$self = ();
  
  return 1;
}

sub is_empty
{
  my $self = shift;
  
  return 0 if exists $self->{ 'BASE_TABLE' } and exists $self->{ 'RECORD_DATA' };
  return 1;
}

# this module handles high-level, structured system/staged database io

sub __get_base_table_fields
{
  my $self = shift;

  boom "record is empty, cannot be read/written" if $self->empty();

  my $base_table = $self->{ 'BASE_TABLE' };
  
  my $des = describe_table();
  return $des->get_fields_list();
}

sub read
{
  my $self = shift;
  
  boom "record is empty, cannot be read" if $self->empty();

  my @res;
  for my $field ( @_ )
    {
    my ( $dst_table, $dst_id, $dst_field ) = $self->resolve_field( $field );
    
    push @res, $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field };
    }

  return wantarray ? @res : shift( @res );
}

sub read_all
{
  my $self = shift;
  
  return $self->read( @{ $self->__get_base_table_fields() } );
}

sub read_hash
{
  my $self = shift;
  
  boom "record is empty, cannot be read" if $self->empty();

  my @res;
  for my $field ( @_ )
    {
    my ( $dst_table, $dst_id, $dst_field ) = $self->resolve_field( $field );
    
    push @res, $field;
    push @res, $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field };
    }

  return wantarray ? @res : { @res };
}

sub read_hash_all
{
  my $self = shift;
  
  return $self->read_hash( @{ $self->__get_base_table_fields() } );
}

sub write
{
  my $self = shift;
  
  boom "record is empty, cannot be read" if $self->empty();

  my $mods_count = 0; # modifications count
  my @data = @_;
  while( @data )
    {
    my $field = shift( @data );
    my $value = shift( @data );

    my ( $dst_table, $dst_id, $dst_field ) = $self->resolve_field( $field, WRITE => 1 );

    # FIXME: check for number values
    next if $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field } eq $value;
    
    $mods_count++;
    
    # mark the record and specific fields as modified
    $self->{ 'RECORD_IMODS' }{ $dst_table }{ $dst_id }++;
    $self->{ 'RECORD_FMODS' }{ $dst_table }{ $dst_id }{ $dst_field }++;
    $self->{ 'RECORD_DATA'  }{ $dst_table }{ $dst_id }{ $dst_field } = $value;
    }

  return $mods_count;
}

### EOF ######################################################################
1;
