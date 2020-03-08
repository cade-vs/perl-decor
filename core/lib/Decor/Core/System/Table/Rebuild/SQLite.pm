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
package Decor::Core::System::Table::Rebuild::SQLite;
use strict;
use Decor::Core::Log;
use Data::Dumper;
use Exception::Sink;
use Data::Lock qw( dlock dunlock );
use Storable qw( lock_nstore lock_retrieve );

use parent 'Decor::Core::System::Table::Rebuild';

##############################################################################

my %MAP_DB_TYPES = (
                     'character varying' => 'varchar',
                   );

sub __save_db_des
{
  my $self = shift;
  my $des  = shift;
  
  my $dbh = $self->get_dbh();
  
  my $db_filename = $dbh->sqlite_db_filename();
  my $des_filename = "$db_filename.dddes";
  
  if( -e $des_filename )
    {
    my $t = time();
    my $backup_filename = "$des_filename.$t";
    my $res = rename( $des_filename, $backup_filename );
    boom "error creating SQlite DB description backup as [$backup_filename]" unless $res;
    }
  
  $des->{ 'SYSTEM' }{ 'DES_FILENAME' } = $des_filename;
  lock_nstore( $des, $des_filename );
  
  return $des;
}

sub __load_db_des
{
  my $self   = shift;
  my $dbh = $self->get_dbh();
  
  my $db_filename = $dbh->sqlite_db_filename();
  my $des_filename = "$db_filename.dddes";

  return {} unless -e $des_filename;
  
  my $des = lock_retrieve( $des_filename );
  boom "error loading SQLite DB description from file [$des_filename]" unless $des;
  print Dumper( $des );
  
  return $des;
}

sub describe_db_table
{
  my $self   = shift;
  my $table  = shift;
  my $schema = shift;
  
  my $sqlite_des = $self->__load_db_des();
  
  return undef unless $sqlite_des;
  return undef unless exists $sqlite_des->{ 'TABLES' }{ $table };
  
  my $db_des = $sqlite_des->{ 'TABLES' }{ $table };

  #print Dumper( $db_des );
  dlock $db_des;
    
  return $db_des;  
  
=pod

  my $db_filename = $dbh->sqlite_db_filename();
  print STDERR "+++++++++++++++++++++++++++ [$db_filename]\n";
  return undef;

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
=cut
}

#-----------------------------------------------------------------------------

sub describe_db_indexes
{
  my $self       = shift;
  my $table      = shift;
  my $schema     = shift;
  
  my $sqlite_des = $self->__load_db_des();
  
  return undef unless $sqlite_des;
  return undef unless exists $sqlite_des->{ 'INDEXES' }{ $table };
  
  my $db_des = $sqlite_des->{ 'INDEXES' }{ $table };

  #print Dumper( $db_des );
  dlock $db_des;
    
  return $db_des;  
=pod  
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
=cut
}

#-----------------------------------------------------------------------------

sub describe_db_sequence
{
  my $self       = shift;
  my $table      = shift;
  my $schema     = shift;

  my $sqlite_des = $self->__load_db_des();

  my $seq_name = 'de_sq_' . lc $table;
  
  return undef unless $sqlite_des;
  return undef unless exists $sqlite_des->{ 'SEQUENCES' }{ $seq_name };
  
  my $sq_des = $sqlite_des->{ 'SEQUENCES' }{ $seq_name };

  #print Dumper( $sq_des );
  dlock $sq_des;
    
  return $sq_des;  
}

#-----------------------------------------------------------------------------

sub sequence_create
{
  my $self   = shift;
  my $des    = shift;
  my $start  = shift || 1;

  my $dbh = $self->get_dbh();

  my $sqlite_des = $self->__load_db_des();
  
  if( ! $sqlite_des->{ 'SYSTEM' }{ 'SYSTEM_SEQUENCES_TABLE' } )
    {
    # SN sequence name, SV sequence value
    my $ss = "CREATE TABLE DE_SYS_SQLITE_SEQUENCES( SN TEXT PRIMARY KEY, SV INTEGER )";
    $dbh->do( $ss );
    $sqlite_des->{ 'SYSTEM' }{ 'SYSTEM_SEQUENCES_TABLE' } = time();
    }

  my $db_seq   = $des->get_db_sequence_name();
  
  my $ss = "DELETE FROM DE_SYS_SQLITE_SEQUENCES WHERE SN = ?";
  de_log_debug( "debug: sequence_create: sql: [$ss]" );
  $dbh->do( $ss, {}, $db_seq );
  
  my $ss = "INSERT INTO DE_SYS_SQLITE_SEQUENCES ( SN, SV ) VALUES ( ?, ? )";
  de_log_debug( "debug: sequence_create: sql: [$ss]" );
  $dbh->do( $ss, {}, $db_seq, $start );
  
  $sqlite_des->{ 'SEQUENCES' }{ $db_seq }{ NAME => $db_seq, SCHEMA => 'n/a', START_VALUE => $start };
  $self->__save_db_des( $sqlite_des );

  return 1;
}

sub sequence_drop
{
  my $self   = shift;
  my $des    = shift;
  my $start  = shift || 1;

  my $dbh = $self->get_dbh();

  my $sqlite_des = $self->__load_db_des();

  my $db_seq   = $des->get_db_sequence_name();
  
  return undef unless exists $sqlite_des->{ 'SEQUENCES' }{ $db_seq };

  my $ss = "DELETE FROM DE_SYS_SQLITE_SEQUENCES WHERE SN = ?";
  de_log_debug( "debug: sequence_drop: sql: [$ss]" );
  $dbh->do( $ss, {}, $db_seq );

  delete $sqlite_des->{ 'SEQUENCES' }{ $db_seq };
  $self->__save_db_des( $sqlite_des );

  return 1;
}

sub sequence_get_current_value
{
  my $self   = shift;
  my $des    = shift;

  my $dbh = $self->get_dbh();

  my $db_seq   = $des->get_db_sequence_name();

  my $ss  = "SELECT SV FROM DE_SYS_SQLITE_SEQUENCES WHERE SN = ?";
  my $sth = $dbh->prepare( $ss );
  $sth->execute( $db_seq ) or die "[$ss] exec failed: " . $sth->errstr;
  my $hr = $sth->fetchrow_hashref();

  return $hr->{ 'SV' };
}

#-----------------------------------------------------------------------------

my %NATIVE_TYPES = (
                   'INT'      => 'INTEGER',
                   'DATE'     => 'INTEGER',
                   'TIME'     => 'REAL',
                   'UTIME'    => 'REAL',
                   
                   'REAL'     => 'REAL',
                   'CHAR'     => 'TEXT',
                   
                   'LINK'     => 'INTEGER',
                   'BACKLINK' => 'INTEGER',
                   'WIDELINK' => 'TEXT',
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
  
  $native = $NATIVE_TYPES{ $name };
  
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
