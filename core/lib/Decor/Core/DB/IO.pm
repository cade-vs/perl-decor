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
use Data::Lock qw( dlock );
use Data::Dumper;

use Decor::Core::DSN;
use Decor::Core::Utils;
use Decor::Core::Describe;
use Decor::Core::Log;
use Decor::Core::Utils;

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
  $self->{ 'SELECT'  } = {};
  
  1;
}

# this module handles low-level database io sql statements and data

sub __reshape
{
  my $self   = shift;
  my $table  = shift;
  
  my $db_name = dsn_get_db_name_by_table( $table );
  my $reshape_class_name = "Decor::Core::DB::IO::$db_name";

  return 0 if ref( $self ) eq $reshape_class_name;
  
  de_log_debug( "$self reshaped as '$reshape_class_name'" );
  my $reshape_file_name = perl_package_to_file( $reshape_class_name );
  require $reshape_file_name;
  bless $self, $reshape_class_name;
  
  1;
}

##############################################################################

sub select
{
  my $self   = shift;
  my $table  = shift;
  my $fields = shift; # can be string, array ref or hash ref
  my $where  = shift;
  my $opts   = shift; 

  $self->__reshape( $table );

  $self->finish();
  
  my $table_des = describe_table( $table );
  my $db_table  = $table_des->get_db_table_name();
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
    if( $fields eq '*' )
      {
      @fields = @{ $table_des->get_fields_list() };
      }
    else
      {
      @fields = split /[\s,]+/, $fields;
      }  
    if( ! @fields )
      {
      boom "empty fields list! requested was [$fields]";
      }
    }  

  
  dlock \@fields;
  $self->{ 'SELECT' }{ 'FIELDS' } = \@fields;
  $self->{ 'SELECT' }{ 'TABLES' }{ $db_table }++;

  my @where;
  my @bind;
  
  push @where, "$db_table.ID > 0";

  my @select_fields;
  for my $field ( @fields )
    {
    my ( $resolved_alias, $resolved_table, $resolved_field ) = $self->__select_resolve_field( $table, $field );
    push @select_fields, "$resolved_alias.$resolved_field";
    }

  # TODO: preprocess $where for linked fields path starting with ^
  # TODO: the same for other clauses

  # TODO: ORDERBY  
  # TODO: GROUPBY
  
  # TODO: use inner or left outer joins, instead of simple where join
  # TODO: add option for inner, outer or full joins!
  push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };
  
  my $limit  = $opts->{ 'LIMIT'  };
  my $offset = $opts->{ 'OFFSET' };
  
  my $limit_clause    = $self->__select_limit_clause( $limit   ) if $limit  > 0;
  my $offset_clause   = $self->__select_offset_clause( $offset ) if $offset > 0;
  my $locking_clause  = "FOR UPDATE" if $opts->{ 'LOCK' }; # FIXME: support more locking clauses
  my $distinct_clause = "DISTINCT" if $opts->{ 'DISTINCT' };

  push @where, $where if $where;
  push @bind,  @{ $opts->{ 'BIND' } } if $opts->{ 'BIND' };

  my $select_tables = join ",\n  ", keys %{ $self->{ 'SELECT' }{ 'TABLES' } };
  my $select_fields = join ",\n  ", @select_fields;
  my $select_where  = "WHERE\n  " . join( "\n AND ", @where );
  
  my $sql_stmt = "SELECT\n $distinct_clause $select_fields\nFROM\n  $select_tables\n$select_where\n$limit_clause\n$offset_clause\n$locking_clause\n";

  de_log_debug( "sql: select: [\n$sql_stmt] with values [@bind]" );
  
  my $dbh = $self->{ 'SELECT' }{ 'DBH' } = dsn_get_dbh_by_table( $table );
  my $sth = $self->{ 'SELECT' }{ 'STH' } = $dbh->prepare( $sql_stmt );
  
  my $retval = $sth->execute( @bind );
  $retval = ( $sth->rows() or '0E0' ) if $retval;

  return $retval;
}

sub __select_limit_clause
{
  boom "cannot be called from the base class";
}

sub __select_offset_clause
{
  boom "cannot be called from the base class";
}

sub __select_resolve_field
{
   my $self   = shift;
   my $table  = uc shift;
   my $field  = uc shift; # userid.info.des.asd.qwe

   my @field = split /\./, $field;
   my $table_now = $table;
   my $field_now = shift @field;
   my $alias_now = $table_now;
   my $alias_key;
   my $alias_next;
   
   while( @field )
     {
     my $fld_des    = describe_table_field( $table_now, $field );
     my $table_next = $fld_des->{ 'LINKED_TABLE' };
     boom "cannot resolve field, current position is [$table_now:$field]" unless $table_next;

     # FIXME: check for cross-DSN links
     
     $alias_key .= "$field.";
     $alias_next = $self->{ 'SELECT' }{ 'TABLES_ALIASES' }{ $alias_key };
     if( ! $alias_next )
       {
       $alias_next = $self->{ 'SELECT' }{ 'TABLES_ALIASES' }{ $alias_key } 
                  = "TA_" . ++$self->{ 'SELECT' }{ 'TABLES_ALIASES_COUNT' };
       }
     
     my $db_table_next = describe_table( $table_next )->get_db_table_name();
     $self->{ 'SELECT' }{ 'TABLES' }{ "$db_table_next $alias_next" }++;

     # FIXME: use inner or left outer joins, instead of simple where join
     # FIXME: add option for inner, outer or full joins!
     $self->{ 'SELECT' }{ 'RESOLVE_WHERE' }{ "$alias_now.$field_now = $alias_next.ID" }++;
     
     $table_now = $table_next;
     $alias_now = $alias_next;
     $field_now = shift @field;
     }

   return ( $alias_now, $table_now, $field_now );
}


#-----------------------------------------------------------------------------

sub fetch
{
  my $self = shift;
  my $sth = $self->{ 'SELECT' }{ 'STH' };
  boom "missing SELECT::STH! call select() before fetch()" unless $sth;

  my $dbh = $self->{ 'SELECT' }{ 'DBH' };
  boom "missing SELECT::DBH! call select() before fetch()" unless $dbh;

  my @data = $sth->fetchrow_array();
  return undef unless @data;

  my $select_fields = $self->{ 'SELECT' }{ 'FIELDS' };
  
  my %data;
  my $c = 0;
  for my $field ( @$select_fields )
    {
    $data{ $field } = $data[ $c++ ];
    }

  return \%data;
}

#-----------------------------------------------------------------------------

sub finish
{
  my $self = shift;

  # FIXME: $self->get_sth();
  my $sth = $self->{ 'SELECT' }{ 'STH' };
  $sth->finish() if $sth;

  $self->reset();
}

#-----------------------------------------------------------------------------

sub rows
{
  my $self = shift;

  # FIXME: $self->get_sth();
  my $sth = $self->{ 'SELECT' }{ 'STH' };
  boom "missing SELECT::STH! call select() before fetch()" unless $sth;

  return $sth->rows();
}

#-----------------------------------------------------------------------------

sub insert
{
  my $self  = shift;
  my $table = uc shift;
  my $data  = shift; # hashref with { field => value }
  my $opts  = shift;

  $self->__reshape( $table );

  my $table_des = describe_table( $table );

  if( ! exists $data->{ "ID" } )
    {
    # detach from the caller and fill ID field
    $data = { %$data }; 
    $data->{ "ID" } ||= $self->get_next_table_id( $table );
    }

print STDERR Dumper( $data );

  # TODO: check if @columns + @values is faster or equal
  my $columns;
  my $values;
  my @values;
  while( my ( $field, $value ) = each %$data )
    {
    $field = uc $field;
    my $fld_des = $table_des->get_field_des( $field );
    my $field_type_name = $fld_des->{ 'TYPE' }{ 'NAME' };
    
    $value = 0 if $field_type_name ne 'CHAR' and $value == 0;
    $columns .= "$field,";
    $values  .= "?,";
print "$field [$value]\n";    
    push @values, $value;
    }
  chop( $columns );
  chop( $values  );

  my $db_table = $table_des->get_db_table_name();
  my $sql_stmt = "INSERT INTO $db_table ( $columns ) values ( $values )";

print STDERR Dumper( $sql_stmt, \@values );

  my $dbh = dsn_get_dbh_by_table( $table );
  my $rc = $dbh->do( $sql_stmt, {}, @values );

  return $rc ? $data->{ "ID" } : 0;
}

#-----------------------------------------------------------------------------

sub update
{
  my $self  = shift;
  my $table = shift;
  my $data  = shift; # hashref with { field => value }
  my $where = shift;
  my $opts  = shift;

  $self->__reshape( $table );

  my @where;
  my @bind;

  my $table_des = describe_table( $table );
  my $db_table  = $table_des->get_db_table();

  my $id = exists $data->{ 'ID' } ? $data->{ 'ID' } : undef;
  if( ! $where and $id )
    {
    push @where, "$db_table.ID = ?" ;
    push @bind, $id;
    }

  # TODO: check if @columns + @values is faster or equal
  my $columns;
  my @values;
  while( my ( $field, $value ) = each %$data )
    {
    $field = uc $field;
    my $fld_des = $table_des->get_field_des( $field );
    my $field_type_name = $fld_des->{ 'TYPE' }{ 'NAME' };
    
    my $value = 0 if $field_type_name ne 'CHAR' and $value == 0;
    $columns .= "$field=?,";
    push @values, $value;
    }
  chop( $columns );

  my $where_clause;
  if( @where )
    {
    $where_clause = "WHERE " . join( ' AND ', @where );
    }

  my $db_table = $table_des->get_db_table();
  my $sql_stmt = "UPDATE $db_table SET $columns $where_clause";

  my $dbh = dsn_get_dbh_by_table( $table );
  my $rc = $dbh->do( $sql_stmt, {}, ( @values, @bind ) );

  return $rc ? $rc : 0;
}

#-----------------------------------------------------------------------------

sub update_id
{
  my $self  = shift;
  my $table = shift;
  my $data  = shift; # hashref with { field => value }
  my $id    = shift;
  my $opts  = shift;

  return $self->update( $table, $data, '^ID = ?', BIND => [ $id ] );
}

#-----------------------------------------------------------------------------

sub get_next_sequence
{
  my $self   = shift;
  my $db_seq = shift; # db sequence name
  my $dsn    = shift || 'MAIN';

  boom "cannot be called from the base class";
  # must be reimplemented inside IO::*
}

#-----------------------------------------------------------------------------

sub get_next_table_id
{
  my $self  = shift;
  my $table = shift;

  $self->__reshape( $table );

  my $des    = describe_table( $table );
  my $db_seq = $des->get_db_sequence_name();
  my $dsn    = $des->get_dsn_name();
  
  my $new_id = $self->get_next_sequence( $db_seq, $dsn );
  de_log_debug( "debug: get_next_table_id: for table [$table] new val [$new_id]" );
  return $new_id;
}

#--- helpers -----------------------------------------------------------------

sub read_first1_hashref
{
  my $self  = shift;
  my $table = shift;
  my $where  = shift;
  my $opts   = shift; 

  $self->select( $table, '*', $where, $opts );
  my $data = $self->fetch();
  $self->finish();
  
  return $data;
}

sub read_first1_by_id_hashref
{
  my $self  = shift;
  my $table = shift;
  my $id    = shift;
  my $opts  = shift; 

  return $self->read_first1_hashref( $table, '^ID = ?', { %$opts, BIND => [ $id ] } );
}


### EOF ######################################################################
1;
