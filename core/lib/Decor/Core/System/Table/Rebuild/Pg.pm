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
package Decor::Core::System::Table::Rebuild::Pg;
use strict;
use Data::Dumper;
use Exception::Sink;
use Data::Lock qw( dlock dunlock );

use parent 'Decor::Core::System::Table::Rebuild';

##############################################################################

my %MAP_DB_TYPES = (
                     'character varying' => 'varchar',
                   );

sub describe_db_table
{
  my $self   = shift;
  my $table  = shift;
  my $schema = shift;
  
  my $dbh = $self->get_dbh();

  my $where_schema;
  my @where_bind;

  push @where_bind, lc $table;
  
  if( $schema )
    {
    $where_schema = "table_schema = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "table_schema = ( select current_schema() )";
    }  
  
  my $des_stmt = qq(

           select
               table_name                  as "table",
               table_schema                as "schema",
               column_name                 as "column",
               data_type                   as "type",
               character_maximum_length    as "len",
               numeric_precision           as "precision",
               numeric_scale               as "scale",
               ( select current_schema() ) as "default_schema"
           from
               information_schema.columns
           where
               table_name = ? AND $where_schema
           order by
               table_name 
  );
  
  #print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $db_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $db_des ||= {};
    my $column  = uc $hr->{ 'COLUMN' };
  
    $hr->{ 'TYPE' } = $MAP_DB_TYPES{ $hr->{ 'TYPE' } } if exists $MAP_DB_TYPES{ $hr->{ 'TYPE' } };
    $db_des->{ $column } = $hr;
    }

  #print Dumper( $db_des );
  dlock $db_des;
    
  return $db_des;  
}

#-----------------------------------------------------------------------------

sub describe_db_indexes
{
  my $self       = shift;
  my $table      = shift;
  my $schema     = shift;
  
  my $dbh = $self->get_dbh();

  my $where_schema;
  my @where_bind;

  push @where_bind, lc $table;
  
  if( $schema )
    {
    $where_schema = "s.nspname = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "s.nspname = ( select current_schema() )";
    }  
  
  my $des_stmt = qq(

            select
                i.relname as "index_name", 
                t.relname as "table", 
                s.nspname as "index_schema",
               ( select current_schema() ) as "default_schema"
            from                                                                  
                pg_index,
                pg_class i,
                pg_class t,
                pg_namespace s
            where             
                    pg_index.indexrelid = i.oid
                and pg_index.indrelid   = t.oid
                and t.relnamespace      = s.oid
                and t.relname           = ?
                and $where_schema
            order by                           
                i.relname

  );
  
  #print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $idx_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $idx_des ||= {};
    my $name  = uc $hr->{ 'INDEX_NAME' };
    
    $idx_des->{ $name } = $hr;
    }

  dlock $idx_des;
  
  return $idx_des;  
}

#-----------------------------------------------------------------------------

sub describe_db_sequence
{
  my $self       = shift;
  my $table      = shift;
  my $schema     = shift;
  
  my $dbh = $self->get_dbh();

  my $where_schema;
  my @where_bind;

  push @where_bind, 'de_sq_' . lc $table;

  if( $schema )
    {
    $where_schema = "sequence_schema = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "sequence_schema = ( select current_schema() )";
    }  
  
  my $des_stmt = qq(
            select 
                sequence_name,
                sequence_schema as "schema",
                start_value
            from 
                information_schema.sequences
            where
                    sequence_name = ?
                and $where_schema
            order by        
                sequence_name
                
  );
  
  #print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $seq_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $seq_des ||= {};
    my $name  = uc $hr->{ 'SEQUENCE_NAME' };

    $seq_des->{ $name } = $hr;
    }

  dlock $seq_des;

  return $seq_des;  
}

#-----------------------------------------------------------------------------

sub sequence_create_sql
{
  my $self   = shift;
  my $des    = shift;
  my $start  = shift || 1;

  my $db_seq   = $des->get_db_sequence_name();
  
  return "CREATE SEQUENCE $db_seq INCREMENT 1 START WITH $start";
}

sub sequence_get_current_value
{
  my $self   = shift;
  my $des    = shift;

  my $db_seq   = $des->get_db_sequence_name();
  
  return $self->select_field_first1( $db_seq, "LAST_VALUE" );
}

#-----------------------------------------------------------------------------

my %NATIVE_TYPES = (
                   'INT'   => 'integer',
                   'DATE'  => 'integer',
                   'TIME'  => 'integer',
                   'UTIME' => 'integer',
                   );

sub get_native_type
{
  my $self = shift;
  my $type = shift;

  my $name = $type->{ 'NAME' };
  my $len  = $type->{ 'LEN'  };
  my $dot  = $type->{ 'DOT'  };
  

  my $native;
  my $base;
  if( $name eq 'INT' )
    {
    if( $len > 0 and $len <= 4 )
      {
      $native = "smallint";
      }
    elsif( $len > 9 )
      {
      $native = "bigint";
      }
    else
      {
      $native = "integer";
      }  
    }
  elsif( $name eq 'CHAR' )
    {
    if( $len > 0 )
      {
      $base = "varchar";
      $native = "$base($len)";
      }
    else
      {
      $native = "text";
      }  
    }
  elsif ( $name eq 'REAL' )
    {
    boom "scale [$dot] cannot be larger than precision [$len]" unless $dot <= $len;
    if( $len > 0 and $dot > 0 )
      {
      $base = "numeric";
      $native = "$base( $len, $dot )";
      }
    else
      {
      $native = "numeric";
      }  
    }
  else
    {
    $native = $NATIVE_TYPES{ $name };
    }

  boom "cannot find native type for decor type [$name]" unless $native;
  $base = $native unless $base;
  return wantarray ? ( $native, $base ) : $native;
}

#--- syntax specifics --------------------------------------------------------

sub table_alter_sql
{
  my $self     = shift;
  my $db_table = shift;
  my $columns  = shift;

  my $sql_columns = join ', ', map { "ADD COLUMN $_" } @$columns;
  
  my $sql_stmt = "ALTER TABLE $db_table $sql_columns";

  return $sql_stmt;
}

##############################################################################
1;
