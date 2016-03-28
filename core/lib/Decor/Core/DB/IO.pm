##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO;
use strict;

use parent 'Decor::Core::DB';
use Exception::Sink;

use Decor::Core::Utils;
use Decor::Core::Describe;
use Decor::Core::Log;

##############################################################################

sub __init
{
  my $self = shift;
  
  1;
}

sub reset
{
  my $self   = shift;

  $self->{ 'TABLE'   } = undef;
  $self->{ 'DBI_STH' } = undef;
  
  1;
}

# this module handles low-level database io sql statements and data

##############################################################################

sub select
{
  my $self   = shift;
  my $table  = shift;
  my $fields = shift; # can be string, array ref or hash ref
  my $where  = shift;
  my $opts   = shift; 

  $self->finish();
  
  my $table_des = describe_table( $table );
  my @fields;
  
  my $fields_ref = ref( $fields );
  if( $fields_ref eq 'ARRAY' )
    {
    @fields = @$fields;
    }
  elsif( $fields_ref eq 'HASH' )  
    {
    @fields = keys %$fields;
    }
  else
    {
    @fields = split /[\s,]+/, $fields;
    }  
    
  ...  
  
}

#-----------------------------------------------------------------------------

sub fetch
{
  my $self = shift;
  
  
}

#-----------------------------------------------------------------------------

sub finish
{
  my $self = shift;

  if( $self->{ 'DBI_STH' } )
    {
    $self->{ 'DBI_STH' }->finish();
    }

  $self->reset();
}

#-----------------------------------------------------------------------------

sub insert
{
  my $self = shift;
  my $table = shift;
  my $data = shift; # hashref with { field => value }


}

#-----------------------------------------------------------------------------

sub update
{
  my $self  = shift;
  my $table = shift;
  my $data  = shift; # hashref with { field => value }
  my $where = shift;

}

#-----------------------------------------------------------------------------

sub update_id
{
  my $self  = shift;
  my $table = shift;
  my $data  = shift; # hashref with { field => value }
  my $id    = shift;

  return $self->update( $table, $data, '.ID = ?', BIND => [ $id ] );
}

#-----------------------------------------------------------------------------

sub get_next_sequence
{
  my $self   = shift;
  my $db_seq = shift; # db sequence name
  
  # must be reimplemented inside IO::*
  
}

#-----------------------------------------------------------------------------

sub get_next_table_id
{
  my $self  = shift;
  my $table = shift;

  my $des    = describe_table( $table );
  my $db_seq = $des->get_db_sequence_name();
  
  return $self->get_next_sequence( $db_seq );
}

### EOF ######################################################################
1;
