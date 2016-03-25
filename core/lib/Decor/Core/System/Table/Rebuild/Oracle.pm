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
package Decor::Core::System::Table::Rebuild::Oracle;
use strict;
use Data::Dumper;
use Exception::Sink;
use Data::Lock qw( dlock dunlock );

use parent 'Decor::Core::System::Table::Rebuild';

##############################################################################

my %MAP_DB_TYPES = (
                   );

sub describe_db_table
{
  my $self   = shift;
  my $table  = shift;
  my $schema = shift;
  
  my $dbh = $self->get_dbh();

  my $where_schema;
  my @where_bind;

  push @where_bind, uc $table;
  
  if( $schema )
    {
    $where_schema = "owner = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "owner = ( select USER from dual )";
    }  
  
  my $des_stmt = qq(

           select
               table_name              as "table",
               owner                   as "schema",
               column_name             as "column",
               data_type               as "type",
               data_length             as "len",
               data_precision          as "precision",
               data_scale              as "scale",
               (select USER from dual) as "default_schema"
           from
               sys.all_tab_columns 
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
    
    $hr->{ 'TYPE' } = lc $hr->{ 'TYPE' };
    
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

  push @where_bind, uc $table;
  
  if( $schema )
    {
    $where_schema = "owner = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "owner = ( select USER from dual )";
    }  
  
  my $des_stmt = qq(

            select
                index_name as "index_name", 
                table_name as "table", 
                owner      as "index_schema",
                ( select USER from dual ) as "default_schema"
            from
                sys.all_indexes
            where
                table_name = ? and $where_schema    
            order by                           
                index_name

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

  print Dumper( $idx_des );
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

  push @where_bind, uc 'de_sq_' . lc $table;

  if( $schema )
    {
    $where_schema = "sequence_owner = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "sequence_owner = ( select USER from dual )";
    }  
  
  my $des_stmt = qq(

            select
                sequence_name   as "sequence_name",
                sequence_owner  as "schema",
                min_value       as "start_value",
                last_number     as "last_number"
            from
                sys.all_sequences
            where
                sequence_name = ? and $where_schema
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

  #print Dumper( $seq_des );
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
  
  return "CREATE SEQUENCE $db_seq INCREMENT BY 1 START WITH $start ORDER";
}

sub sequence_get_current_value
{
  my $self   = shift;
  my $des    = shift;

  my $table     = $des->get_table_name();
  my $table_des = $des->get_table_des();
  my $db_seq   = $des->get_db_sequence_name();
  my $schema    = $table_des->{ 'SCHEMA' };

  my $seq_db_des = $self->describe_db_sequence( $table, $schema );

  return $seq_db_des->{ $db_seq }{ 'LAST_NUMBER' };
}

#-----------------------------------------------------------------------------

my %NATIVE_TYPES = (
                   'DATE'  => [ 'number', 'number(38)' ],
                   'TIME'  => [ 'number', 'number(38)' ],
                   'UTIME' => [ 'number', 'number(38)' ],
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
    if( $len > 0 )
      {
      $base = "number";
      $native = "$base($len)";
      }
    else
      {
      $base = "number";
      $native = "$base(38)"; # as described in oracle docs
      }  
    }
  elsif( $name eq 'CHAR' )
    {
    if( $len > 0 and $len < 4000 ) # TODO: unicode support?
      {
      $base = "varchar2";
      $native = "$base($len)";
      }
    else
      {
      $native = "clob";
      }  
    }
  elsif ( $name eq 'REAL' )
    {
    boom "scale [$dot] cannot be larger than precision [$len]" unless $dot <= $len;
    if( $len > 0 and $dot > 0 )
      {
      $base = "number";
      $native = "$base( $len, $dot )";
      }
    else
      {
      $native = "number";
      }  
    }
  else
    {
    ( $base, $native ) = @{ $NATIVE_TYPES{ $name } };
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

  my $sql_columns = join ', ', @$columns;
  
  my $sql_stmt = "ALTER TABLE $db_table ADD ( $sql_columns )";

  return $sql_stmt;
}

##############################################################################
1;
