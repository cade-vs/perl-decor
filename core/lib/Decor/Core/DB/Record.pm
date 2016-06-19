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

sub create
{
  my $self  = shift;
  
  my $table = shift;

  boom "invalid TABLE name [$table]" unless des_exists( $table );

  $self->reset();

  $self->{ 'BASE_TABLE' } = $table;

  my $new_id = $self->__create_empty_data( $table );
  
  
}

sub load
{
  my $self  = shift;
  
  my $table = shift;
  my $id    = shift;

  boom "invalid TABLE name [$table]" unless des_exists( $table );
  de_check_id_boom(   $id,    "invalid ID [$id]"            );
  
  $self->reset();

  # FIXME: try to load record first

  $self->{ 'BASE_TABLE' } = $table;
  $self->{ 'BASE_ID'    } = $id;
  
}

#-----------------------------------------------------------------------------

# this module handles high-level, structured system/staged database io

sub __get_base_table_fields
{
  my $self = shift;

  boom "record is empty, cannot be read/written" if $self->empty();

  my $base_table = $self->{ 'BASE_TABLE' };
  
  my $des = describe_table( $base_table );
  return $des->get_fields_list();
}

sub read
{
  my $self = shift;
  
  boom "record is empty, cannot be read" if $self->empty();

  my @res;
  for my $field ( @_ )
    {
    my ( $dst_table, $dst_id, $dst_field ) = $self->__resolve_field( $field );
    
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
    my ( $dst_table, $dst_id, $dst_field ) = $self->__resolve_field( $field );
    
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

    my ( $dst_table, $dst_id, $dst_field ) = $self->__resolve_field( $field, WRITE => 1 );

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

sub __resolve_field
{
  my $self = shift;
  
  my $field = uc shift;
  
  my $base_table = $self->{ 'BASE_TABLE' };
  my $base_id    = $self->{ 'BASE_ID'    };
  
  if( $field !~ /\./ ) # if no path was given, i.e. field.field.field
    {
    boom "cannot resolve table/field [$base_table/$field]" unless des_exists( $base_table, $field );
    return ( $base_table, $field, $base_id );
    }

  my @fields = split /\./, $field;
  
  my $current_table = $base_table;
  my $current_field = shift @fields;
  my $current_id    = $base_id;
  while( @fields )
    {
    my $field_des = describe_table_field( $current_table, $current_field );
    
    my $linked_table = $field_des->{ 'LINKED_TABLE' };
    boom "cannot resolve table/field [$current_table/$current_field] invalid linked table [$linked_table]" unless des_exists( $linked_table );
    
    
    
    }

#  my $des = describe_table( $base_table );
  
  
}

### EOF ######################################################################
1;
