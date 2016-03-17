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
package Decor::Core::System::Table::Rebuild::Pg;
use strict;
use Data::Dumper;
use Exception::Sink;

use parent 'Decor::Core::System::Table::Rebuild';

##############################################################################

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
  
  print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $db_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $db_des ||= {};
    my $column  = uc $hr->{ 'COLUMN' };
    
    $db_des->{ $column } = $hr;
    }

  print Dumper( $db_des );
    
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
  
  print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $idx_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $idx_des ||= {};
    my $name  = uc $hr->{ 'INDEX_NAME' };
    
    $idx_des->{ $name } = $hr;
    }

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

  push @where_bind, lc $table;

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
  
  print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my $seq_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $seq_des ||= {};
    my $name  = uc $hr->{ 'SEQUENCE_NAME' };
    
    $seq_des->{ $name } = $hr;
    }

  return $seq_des;  
}

#-----------------------------------------------------------------------------

sub sequence_get_current_value
{
  my $self = shift;
  my $name = shift;

  my $dbh = $self->get_dbh();
  
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
      $native = "varchar($len)";
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
      $native = "numeric( $len, $dot )";
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
  return $native;
}



sub get_decor_type
{
  my $self = shift;

  boom "cannot call get_decor_type() from a base class";
  
}

##############################################################################
1;
