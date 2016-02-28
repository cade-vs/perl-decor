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

sub rebuild
{
  my $self = shift;
  my $des  = shift;
  my $dbh  = shift;
  
  my $table = $des->get_table_name();
  my $table_des = $des->get_table_des();
  my $schema = $table_des->{ 'SCHEMA' };
  
  my $fields = $des->get_fields_list();
  
  my $table_db_des = $self->describe_db_table( $table, $schema );
  my $index_db_des = $self->describe_db_indexes( $table, $schema );
  my $seq_db_des   = $self->describe_db_sequences( $schema );
  
  print Dumper( $table, $schema, $table_db_des, $index_db_des, $seq_db_des );
}

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

sub describe_db_sequences
{
  my $self = shift;
  
  boom "cannot call describe_db_sequences() from a base class";
}

sub get_dbh
{
  my $self = shift;

  return $self->{ 'DBH' };
}

1;
