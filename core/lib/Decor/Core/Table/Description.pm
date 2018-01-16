##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Description;
use strict;

use parent 'Decor::Core::Base';
use parent 'Decor::Shared::Table::Description';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

use Decor::Shared::Utils;
use Decor::Core::Log;
use Decor::Core::Config;

##############################################################################

sub describe
{
  my $self = shift;
  
  return Decor::Core::Describe::describe_table( @_ );
}

sub is_virtual
{
  my $self = shift;
  
  return $self->{ '@' }{ 'VIRTUAL' };
}

sub get_table_type
{
  my $self = shift;
  
  return $self->{ '@' }{ 'TYPE' };
}

sub get_table_name
{
  my $self = shift;
  
  return $self->{ '@' }{ '_TABLE_NAME' };
}

sub get_fields_list
{
  my $self = shift;
  
  return $self->{ '@' }{ '_FIELDS_LIST' };
}

sub get_indexes_list
{
  my $self = shift;
  
  return $self->{ '@' }{ '_INDEXES_LIST' };
}

sub get_dos_list
{
  my $self = shift;
  
  return $self->{ '@' }{ '_DOS_LIST' };
}

sub get_index_des
{
  my $self  =    shift;
  my $index = uc shift;

  if( ! exists $self->{ 'INDEX' }{ $index } )
    {
    my $table = $self->get_table_name();
    boom "unknown index [$index] for table [$table]";
    }

  return $self->{ 'INDEX' }{ $index };
}

sub get_dsn_name
{
  my $self  =    shift;

  return $self->{ '@' }{ 'DSN' };
}

sub get_table_dbh
{
  my $self  =    shift;

  my $table = $self->{ '@' }{ '_TABLE_NAME' };
  
  return dsn_get_dbh_by_table( $table );
}

sub get_table_schema
{
  my $self = shift;

  return $self->{ '@' }{ 'SCHEMA' };
}

sub get_db_table_name
{
  my $self = shift;

  my $table  = $self->get_table_name();
  my $schema = $self->get_table_schema();
  $schema = "$schema." if $schema;

  return "${schema}$table";
}

sub get_db_sequence_name
{
  my $self = shift;

  my $table  = $self->get_table_name();
  my $schema = $self->get_table_schema();
  $schema = "$schema." if $schema;

  return "${schema}DE_SQ_$table";
}

### EOF ######################################################################
1;
