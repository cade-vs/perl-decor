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
package Decor::Core::System::Table::Rebuild;
use strict;
use Exception::Sink;
use Data::Dumper;

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my $dbh = shift;
  
  my %args = @_;
  
  my $self = {
             'DBH' => $dbh,
             };
  bless $self, $class;

#  de_obj_add_debug_info( $self );
  return $self;
}

### FOR REIMPLEMENTATION ##################################################### 

sub describe_db_table
{
  my $self = shift;
  
  boom "cannot call describe_db_table() from a base class";
}

sub describe_db_index
{
  my $self = shift;
  
  boom "cannot call describe_db_index() from a base class";
}

sub describe_db_sequence
{
  my $self = shift;
  
  boom "cannot call describe_db_sequences() from a base class";
}

sub sequence_get_current_value
{
  my $self = shift;
  
  boom "cannot call describe_db_sequences() from a base class";
}

sub sequence_create_sql
{
  my $self = shift;
  
  boom "cannot call describe_db_sequences() from a base class";
}

sub get_dbh
{
  my $self = shift;

  return $self->{ 'DBH' };
}

sub get_native_type
{
  my $self = shift;

  boom "cannot call get_native_type() from a base class";
}

############################################################################## 

sub select_field_first1
{
  my $self     = shift;
  my $db_table = shift;
  my $field    = shift;

  my $dbh   = $self->get_dbh();
  
  my $ar = $dbh->selectrow_arrayref( "SELECT $field FROM $db_table" );

  return undef unless $ar;
  return $ar->[ 0 ];
}

sub get_table_max_id
{
  my $self  = shift;
  my $db_table = shift;

  return $self->select_field_first1( $db_table, "MAX(ID)" );
}

#--- syntax specifics --------------------------------------------------------

sub table_alter_sql
{
  boom "cannot call table_alter_sql() from a base class";
}

###EOF######################################################################## 
1;
