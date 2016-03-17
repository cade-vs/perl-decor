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

sub sequence_create
{
  my $self = shift;
  
  boom "cannot call describe_db_sequences() from a base class";
}

sub sequence_reset
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

sub get_decor_type
{
  my $self = shift;

  boom "cannot call get_decor_type() from a base class";
  
}

1;
