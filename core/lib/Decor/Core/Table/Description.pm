##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Description;
use strict;

use parent 'Decor::Core::Base';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

use Decor::Core::Log;
use Decor::Core::Utils;
use Decor::Core::Config;

##############################################################################

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

sub get_table_des
{
  my $self  =    shift;
  
  return $self->{ '@' };
}

sub get_field_des
{
  my $self  =    shift;
  my $field = uc shift;

  if( ! exists $self->{ 'FIELD' }{ $field } )
    {
    my $table = $self->get_table_name();
    boom "unknown field [$field] for table [$table]";
    }

  return $self->{ 'FIELD' }{ $field };
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

  return "${schema}$table";
}

### EOF ######################################################################
1;
