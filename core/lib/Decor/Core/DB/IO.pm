##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
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

# TODO: add profiles check and support
# TODO: add select _OWNER* and _READ* 'in' sets
# TODO: add select READ for taint mode FIELDS check
# TODO: add dot-path where fields support for update()
# TODO: add resolve checks for inter cross-DSN links

# TODO: FIXME: use only integer groups, use names only for mapping

##############################################################################

sub __init
{
  my $self = shift;
  
  1;
}

sub reset
{
  my $self   = shift;

  delete $self->{ 'TABLE'   };
  delete $self->{ 'SELECT'  };
  
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
  my $table  = uc shift;
  my $fields = shift; # can be string, array ref or hash ref
  my $where  = shift;
  my $opts   = shift; 

  $self->__reshape( $table );

  $self->finish();

  my $profile = $self->__get_profile();
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'READ', $table );
    }

  $fields = '*' if $fields eq '';
  
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

  s/^\.// for @fields; # remove leading anchor (syntax sugar really)
    
  
  dlock \@fields;
  $self->{ 'SELECT' }{ 'FIELDS'     } = \@fields;
  $self->{ 'SELECT' }{ 'TABLES'     }{ $db_table }++;
  $self->{ 'SELECT' }{ 'BASE_TABLE' } = $table;

  my @where;
  my @bind;

  push @where, "$db_table._ID > 0";

  push @where, $self->__get_row_access_where_list( $table, 'OWNER', 'READ' );
  
  # resolve fields in select
  my @select_fields;
  for my $field ( @fields )
    {
    # TODO: handle AGGREGATE functions, with checking allowed funcs
    my ( $resolved_alias, $resolved_table, $resolved_field ) = $self->__select_resolve_field( $table, $field );
    push @select_fields, "$resolved_alias.$resolved_field";
    }

  # resolve fields in where clause
  $where = $self->__resolve_clause_fields( $table, $where ) if $where ne '';

  my $order_by = $opts->{ 'ORDER_BY' };
  $order_by = "ORDER BY\n    " . $self->__resolve_clause_fields( $table, $order_by ) if $order_by ne '';

  my $group_by = $opts->{ 'GROUP_BY' };
  $group_by = "GROUP BY\n    " . $self->__resolve_clause_fields( $table, $group_by ) if $group_by ne '';

  # TODO: use inner or left outer joins, instead of simple where join
  # TODO: add option for inner, outer or full joins!

  push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };
  
  my $limit  = $opts->{ 'LIMIT'  };
  my $offset = $opts->{ 'OFFSET' };
  
  my $limit_clause    = $self->__select_limit_clause( $limit   ) . "\n" if $limit  > 0;
  my $offset_clause   = $self->__select_offset_clause( $offset ) . "\n" if $offset > 0;
  my $locking_clause  = "FOR UPDATE" if $opts->{ 'LOCK' }; # FIXME: support more locking clauses
  my $distinct_clause = "DISTINCT\n    " if $opts->{ 'DISTINCT' };

  # TODO: check for clauses collisions, i.e. FOR_UPDATE cannot be used with GROUP_BY, DISTINCT, etc.
  #       Oracle:     You cannot specify this clause with the following other constructs: the DISTINCT operator, CURSOR expression, set operators, group_by_clause, or aggregate functions.
  #       PostgreSQL: ...cannot be used with GROUP_BY, HAVING, WINDOW, DISTINCT, with UNION/INTERSECT/EXCEPT result/input

  # TODO: support for SKIP LOCKED, NOWAIT locking

  push @where, $where if $where;
  push @bind,  @{ $opts->{ 'BIND' } } if $opts->{ 'BIND' };

  my $select_tables = join ",\n    ", keys %{ $self->{ 'SELECT' }{ 'TABLES' } };
  my $select_fields = join ",\n    ", @select_fields;
  my $select_where  = "WHERE\n    " . join( "\n    AND ", @where );
  
  my $sql_stmt = "SELECT\n    $distinct_clause$select_fields\nFROM\n    $select_tables\n$select_where\n$group_by\n$order_by\n$limit_clause$offset_clause$locking_clause\n";

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
  #   my $field_now = shift @field;
  my $field_now;
  my $alias_now = $table_now;
  my $alias_key;
  my $alias_next;

  my $profile = $self->__get_profile();

  #   while( @field )
  while(4)
    {
    $field_now = shift @field;

    if( $profile and $self->taint_mode_get( 'FIELDS' ) )
      {
      $profile->check_access_table_field_boom( 'READ', $table_now, $field_now );
      }
    my $fld_des = describe_table_field( $table_now, $field_now );

    if( @field == 0 )
      {
      return ( $alias_now, $table_now, $field_now );
      } 

    my $table_next = $fld_des->{ 'LINKED_TABLE' };
    boom "cannot resolve field, current position is [$table_now:$field_now]" unless $table_next;

    # FIXME: check for cross-DSN links
   
    $alias_key .= "$field.";
    $alias_next = $self->{ 'SELECT' }{ 'TABLES_ALIASES' }{ $alias_key };
    if( ! $alias_next )
      {
      $alias_next = $self->{ 'SELECT' }{ 'TABLES_ALIASES' }{ $alias_key } 
                 = "_TABLE_ALIAS_" . ++$self->{ 'SELECT' }{ 'TABLES_ALIASES_COUNT' };
      }
   
    my $db_table_next = describe_table( $table_next )->get_db_table_name();
    $self->{ 'SELECT' }{ 'TABLES' }{ "$db_table_next   $alias_next" }++;

    # FIXME: use inner or left outer joins, instead of simple where join
    # FIXME: add option for inner, outer or full joins!
    $self->{ 'SELECT' }{ 'RESOLVE_WHERE' }{ "$alias_now.$field_now = $alias_next._ID" }++;
   
    $table_now = $table_next;
    $alias_now = $alias_next;
    #     $field_now = shift @field;
  }

}

sub __resolve_single_field
{
   my $self   = shift;
   my $table  = shift;
   my $field  = uc shift; # userid.info.des.asd.qwe

print Dumper( "__where_resolve_field = [$field]" );

   $field = substr( $field, 1 ); # skips leading anchor (.)

   my ( $resolved_alias, $resolved_table, $resolved_field ) = $self->__select_resolve_field( $table, $field );

print Dumper( \@_, "$resolved_alias.$resolved_field" );


   return "$resolved_alias.$resolved_field";
}

sub __resolve_clause_fields
{
   my $self   = shift;
   my $table  = shift;
   my $clause = shift;

  $clause =~ s/((?<![A-Z_0-9])|^)((\.[A-Z_0-9]+)+)/$self->__resolve_single_field( $table, $2 )/gie;
  
  return $clause;
}

sub __get_row_access_where_list
{
  my $self  = shift;
  my $table = shift;

  my $profile = $self->__get_profile();
  return () unless $profile and $self->taint_mode_get( 'ROWS' );

  my $groups_string = $profile->get_groups_string();

  my $table_des = describe_table( $table );
  my $fields    = $table_des->get_fields_list();
  my $db_table  = $table_des->get_db_table_name();
  
  my @where;
  for my $oper ( @_ )
    {
    my $sccnt = 0; # security checks count
    for my $field ( @$fields )
      {
      next unless $field =~ /^_${oper}(_[A-Z_0-9]+)?$/;

      my $where = "( $db_table.$field IN ( $groups_string ) )";
      push @where, $where;
      }
    } 
  
  return @where;  
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

  my $profile = $self->__get_profile();
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'INSERT', $table );
    }

  my $table_des = describe_table( $table );

  if( ! exists $data->{ "_ID" } )
    {
    # detach from the caller and fill ID field
    $data = { %$data }; 
    $data->{ "_ID" } ||= $self->get_next_table_id( $table );
    }

#print STDERR Dumper( $data );

  # TODO: check if @columns + @values is faster or equal
  my $columns;
  my $values;
  my @values;
  while( my ( $field, $value ) = each %$data )
    {
    $field = uc $field;
    if( $profile and $self->taint_mode_get( 'FIELDS' ) )
      {
      $profile->check_access_table_field_boom( 'INSERT', $table, $field );
      }

    my $fld_des = $table_des->get_field_des( $field );
    my $field_type_name = $fld_des->{ 'TYPE' }{ 'NAME' };
    
    $value = 0 if $field_type_name ne 'CHAR' and $value == 0;
    $columns .= "$field,";
    $values  .= "?,";
#print "$field [$value]\n";    
    push @values, $value;
    }
  chop( $columns );
  chop( $values  );

  my $db_table = $table_des->get_db_table_name();
  my $sql_stmt = "INSERT INTO\n    $db_table\n    ( $columns )\nVALUES\n    ( $values )";

  de_log_debug( "sql: update: [\n$sql_stmt] with values [@values]\n" . Dumper( $data ) );

#print STDERR Dumper( '-' x 72, __PACKAGE__ . "::INSERT: table [$table] data/sql/values", $data, $sql_stmt, \@values );

  my $dbh = dsn_get_dbh_by_table( $table );
  my $rc = $dbh->do( $sql_stmt, {}, @values );

  return $rc ? $data->{ "_ID" } : 0;
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

  my $profile = $self->__get_profile();
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'UPDATE', $table );
    }

  my @where;
  my @bind;

  my $table_des = describe_table( $table );
  my $db_table  = $table_des->get_db_table_name();

  if( $where ne '' )
    {
    # FIXME: different databases support vastly differs as well :(
    # resolve fields in where clause
    #$where = $self->__resolve_clause_fields( $table, $where );

    push @where, $where;
    push @bind,  @{ $opts->{ 'BIND' } || [] };
    }
  else
    {
    my $id = exists $data->{ '_ID' } ? $data->{ '_ID' } : undef;
    if( $id )
      {
      push @where, "$db_table._ID = ?" ;
      push @bind, $id;
      }
    }

  push @where, $self->__get_row_access_where_list( $table, 'OWNER', 'UPDATE' );

  # TODO: check if @columns + @values is faster or equal
  my $columns;
  my @values;
  while( my ( $field, $value ) = each %$data )
    {
    $field = uc $field;
    if( $profile and $self->taint_mode_get( 'FIELDS' ) )
      {
      $profile->check_access_table_field_boom( 'INSERT', $table, $field );
      }

    my $fld_des = $table_des->get_field_des( $field );
    my $field_type_name = $fld_des->{ 'TYPE' }{ 'NAME' };
    
    $value = 0 if $field_type_name ne 'CHAR' and $value == 0;
    $columns .= "$field=?,";
    push @values, $value;
    }
  chop( $columns );

  # FIXME: different databases support vastly differs as well :(
  #push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  #delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };

  # TODO: support for _UG_* fields

  my $where_clause;
  if( @where )
    {
    $where_clause = join( "\n    AND ", @where );
    }

  my $db_table = $table_des->get_db_table_name();
  my $sql_stmt = "UPDATE\n    $db_table\nSET\n    $columns\nWHERE\n    $where_clause";

  de_log_debug( "sql: update: [\n$sql_stmt] with values [@bind]" );

#print STDERR Dumper( '-' x 72, __PACKAGE__ . "::UPDATE: table [$table] data/sql/values/where/bind", $data, $sql_stmt, \@values, $where_clause, \@bind, $self );

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

  return $self->update( $table, $data, '_ID = ?', { BIND => [ $id ] } );
  # FIXME: must be resolved ID, i.e. ^ID
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

  return $self->read_first1_hashref( $table, '._ID = ?', { %$opts, BIND => [ $id ] } );
}


### EOF ######################################################################
1;
