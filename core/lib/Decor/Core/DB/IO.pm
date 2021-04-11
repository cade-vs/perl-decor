##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
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
use Encode;    

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::DSN;
use Decor::Core::Describe;
use Decor::Core::Log;

##############################################################################

# TODO: add select _OWNER* and _READ* 'in' sets
# TODO: check for valid opers
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
  delete $self->{ 'VIRTUAL' };
  
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
  
  $opts = { 'BIND' => $opts } if ref( $opts ) eq 'ARRAY'; # directly BIND values

  boom "BIND opt must be ARRAY ref" if $opts->{ 'BIND' } and ref( $opts->{ 'BIND' } ) ne 'ARRAY';

  $self->reset();

  $self->__reshape( $table );

  $self->finish();

  my $profile = $self->__get_profile();
  if( $profile and $self->taint_mode_get( 'TABLE' ) and ! $profile->check_access( 966 ) )
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
      if( $profile and $self->taint_mode_get( 'FIELDS' ) and ! $profile->check_access( 966 ) )
        {
        @fields = grep { $profile->check_access_table_field( 'READ', $table, $_ ) } @fields;
        }
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

  @fields = sort @fields if de_debug(); # TODO: keep description file order  
  
  dlock \@fields;
  $self->{ 'SELECT' }{ 'FIELDS'     } = \@fields;
  $self->{ 'SELECT' }{ 'TABLES'     }{ $db_table }++;
  $self->{ 'SELECT' }{ 'BASE_TABLE' } = $table;

  if( $table_des->is_virtual() )
    {
    $self->{ 'VIRTUAL' }++;
    return '0E0';
    }

  my @where;
  my @bind;

  push @where, "$db_table._ID > 0" unless $opts->{ 'MANUAL' };

  push @where, $self->__get_row_access_where_list( $table, 'OWNER', 'READ' );
  
  # resolve fields in select
  my @select_fields;
  for my $field ( @fields )
    {
    # TODO: handle AGGREGATE functions, with checking allowed funcs
    if( $field eq 'COUNT(*)' )
      {
      # special case COUNT(*)
      push @select_fields, 'COUNT(*)';
      next;
      };
    
    my ( $resolved_alias, $resolved_table, $resolved_field ) = $self->__select_resolve_field( $table, $field );
    push @select_fields, "$resolved_alias.$resolved_field";
    }

  # resolve fields in where clause
  $where = $self->__resolve_clause_fields( $table, $where ) if $where ne '';

  my $order_by = $opts->{ 'ORDER_BY' };
  $order_by = "ORDER BY\n    " . $self->__resolve_all_fields( $table, $order_by, { 'UNTAINT_FIELDS' => 1 } ) if $order_by ne '';

  my $group_by = $opts->{ 'GROUP_BY' };
  $group_by = "GROUP BY\n    " . $self->__resolve_all_fields( $table, $group_by, { 'UNTAINT_FIELDS' => 1 } ) if $group_by ne '';

  # TODO: use inner or left outer joins, instead of simple where join
  # TODO: add option for inner, outer or full joins!

  push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };
  
  my $limit  = $opts->{ 'LIMIT'  };
  my $offset = $opts->{ 'OFFSET' };
  
  my $limit_clause    = $self->__select_limit_clause( $limit   ) . "\n" if $limit  > 0;
  my $offset_clause   = $self->__select_offset_clause( $offset ) . "\n" if $offset > 0;
  my $locking_clause  = $self->__select_for_update_clause(     ) . "\n" if $opts->{ 'LOCK' }; # FIXME: support more locking clauses
  my $distinct_clause = "DISTINCT\n    " if $opts->{ 'DISTINCT' };

  # TODO: check for clauses collisions, i.e. FOR_UPDATE cannot be used with GROUP_BY, DISTINCT, etc.
  #       Oracle:     You cannot specify this clause with the following other constructs: the DISTINCT operator, CURSOR expression, set operators, group_by_clause, or aggregate functions.
  #       PostgreSQL: ...cannot be used with GROUP_BY, HAVING, WINDOW, DISTINCT, with UNION/INTERSECT/EXCEPT result/input

  # TODO: support for SKIP LOCKED, NOWAIT locking

  push @where, $where if $where;
  push @bind,  @{ $opts->{ 'BIND' } } if $opts->{ 'BIND' };

  #print STDERR Dumper( '+--'x77, $self->{ 'SELECT' }, '+--'x77,);

  my $select_tables = $db_table . "\n" . __explain_join_tree( $self->{ 'SELECT' }{ 'JOIN_TREE' }{ 'NEXT' } );
  my $select_fields = join ",\n    ", @select_fields;
  my $select_where  = "WHERE\n    " . join( "\n    AND ", @where );
  
  my $sql_stmt = "SELECT\n    $distinct_clause$select_fields\nFROM\n    $select_tables\n$select_where\n$group_by\n$order_by\n$limit_clause$offset_clause$locking_clause\n";

  de_log_debug( "sql: ".__PACKAGE__."::select:\n---BEGIN SQL---\n$sql_stmt\n---SQL BIND ARGS---\n@bind\n---END SQL---" );

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
  my $opt    = shift || {};

  my @field = split /\./, $field;
  my $table_now = $table;
  #   my $field_now = shift @field;
  my $field_now;
  my $alias_now = $table_now;
  my $alias_key;
  my $alias_next;

  my $profile = $self->__get_profile();

  $self->{ 'SELECT' }{ 'JOIN_TREE' } ||= {};

  my $join_tree = $self->{ 'SELECT' }{ 'JOIN_TREE' }; # new/next join

  #   while( @field )
  while(4)
    {
    $field_now = shift @field;

    if( ! $opt->{ 'UNTAINT_FIELDS' } and $profile and $self->taint_mode_get( 'FIELDS' ) )
      {
      boom "cannot get across field, READ/CROSS denied, current position is [$table_now:$field_now]" 
          unless
             $profile->check_access_table_field( 'READ',  $table_now, $field_now )
          or 
             $profile->check_access_table_field( 'CROSS', $table_now, $field_now );
      }

    if( @field == 0 )
      {
      return ( $alias_now, $table_now, $field_now );
      } 

    my $fld_des = describe_table_field( $table_now, $field_now );
    boom "cannot resolve field, current position is NOT A LINK [$table_now:$field_now] in field path [$field]" unless $fld_des->is_linked();

    my $table_next = $fld_des->{ 'LINKED_TABLE' };
    boom "cannot resolve field, current position is [$table_now:$field_now] in field path [$field]" unless des_exists( $table_next );

    # FIXME: check for cross-DSN links
    if( ! exists $join_tree->{ 'NEXT' }{ $field_now } )
      {
      #print STDERR Dumper( '>'x44, "NEW FIELD: $field_now" );
      $join_tree = $join_tree->{ 'NEXT' }{ $field_now } = {};

      my $alias_counter = sprintf( "%04d", ++ $self->{ 'SELECT' }{ 'TABLES_ALIASES_COUNT' } );
      boom "__select_resolve_field(): table alias limit of 9999 is already reached" unless $alias_counter < 9998;
      $join_tree->{ 'TABLE'       } = $table_next;
      my $db_table_next = $join_tree->{ 'DB_TABLE'    } = describe_table( $table_next )->get_db_table_name();
      $alias_next       = $join_tree->{ 'TABLE_ALIAS' } = "_TABLE_ALIAS_$alias_counter";

      my $join_type = "INNER "; # to be precise :)
      $join_type = "RIGHT OUTER " if $opt->{ 'JOIN_TYPE' } eq 'OUTER';
      $join_tree->{ 'JOIN' } = $join_type . "JOIN $db_table_next $alias_next";
      $join_tree->{ 'ON'   } = "ON $alias_now.$field_now = $alias_next._ID";
      }
    else
      {  
      $join_tree  = $join_tree->{ 'NEXT' }{ $field_now };
      $alias_next = $join_tree->{ 'TABLE_ALIAS' };
      }

    #print STDERR Dumper( '1*'x77, $self->{ 'SELECT' }{ 'JOIN_TREE' }, '+'x77,);

    $table_now = $table_next;
    $alias_now = $alias_next;
  }
}

sub __explain_join_tree
{
  my $join_tree = shift;
  my $level     = shift() + 1;

  my $text;

  my $padding = '  ' x ( $level + 1 );

  return unless $join_tree;
  for my $field ( sort { $join_tree->{ $a }{ 'TABLE_ALIAS' } cmp $join_tree->{ $b }{ 'TABLE_ALIAS' } } keys %$join_tree )
    {
    my $join_next = $join_tree->{ $field };

    my $join = $join_next->{ 'JOIN' };
    my $next = exists $join_next->{ 'NEXT' } ? __explain_join_tree( $join_next->{ 'NEXT' }, $level ) : undef;
    my $on   = $join_next->{ 'ON'   };
    $text .= "$padding$join\n";
    $text .= $next;
    $text .= "$padding$on\n";
    }
  
  return $text;  
}

sub __resolve_single_field
{
   my $self   = shift;
   my $table  = shift;
   my $field  = uc shift; # userid.info.des.asd.qwe
   my $opt    = shift || {};

#print Dumper( "__resolve_single_field = [$field]" );

   $field =~ s/^\.//; # skips leading anchor (.)

   my ( $resolved_alias, $resolved_table, $resolved_field ) = $self->__select_resolve_field( $table, $field, $opt );

#print Dumper( \@_, "$resolved_alias.$resolved_field" );


   return "$resolved_alias.$resolved_field";
}

sub __resolve_clause_fields
{
   my $self   = shift;
   my $table  = shift;
   my $clause = shift;
   my $opt    = shift || {};

#print Dumper( "__resolve_clause_fields = [$table] [$clause]" );

   $clause =~ s/((?<![A-Z_0-9])|^)((\.[A-Z_0-9]+)+)/$self->__resolve_single_field( $table, $2, $opt )/gie;
  
   return $clause;
}

sub __resolve_all_fields
{
   my $self   = shift;
   my $table  = shift;
   my $fields = shift;
   my $opt    = shift || {};

   my @fields = split /,/, $fields;
   for( @fields )
     {
     s/^\.//;
     $_ =~ s/^\s*([A-Z_0-9\.]+)/$self->__resolve_single_field( $table, $1, $opt )/ie;
     }
  
  return join( ',', @fields );
}

sub __get_row_access_where_list
{
  my $self  = shift;
  my $table = shift;

  my $profile = $self->__get_profile();
  if( $profile )
    {
    return () if     $profile->has_root_access();
    return () if     $profile->check_access( 961 ); # ignore ownership globally
    return () unless $self->taint_mode_get( 'ROWS' );
    }
  else
    {
    return ();
    }  

  my $groups_string = $profile->get_groups_string();

  my $table_des = describe_table( $table );
  my $fields    = $table_des->get_fields_list();
  my $db_table  = $table_des->get_db_table_name();
  
  my @where;
  for my $oper ( @_ )
    {
    # TODO: check for valid opers
    my $sccnt = 0; # security checks count
    my @oper_where;
    for my $field ( @$fields )
      {
#print STDERR "+++++++++++++++++++++++++++ [$oper][$field]\n";
      next unless $field =~ /^_${oper}(_[A-Z_0-9]+)?$/;

      push @oper_where, "( $db_table.$field IN ( $groups_string ) )";
#print STDERR "+++++++++++++++++++++++++++ ( $db_table.$field IN ( $groups_string ) )\n";
      }
    next unless @oper_where > 0;
    my $oper_where = join ' OR ', @oper_where;
    push @where, "( $oper_where )";
    } 

  
  return @where;  
}

#-----------------------------------------------------------------------------

sub fetch
{
  my $self = shift;

  return undef if $self->{ 'VIRTUAL' };
  return undef if $self->{ 'SELECT' }{ 'EOD' };
  
  my $sth = $self->{ 'SELECT' }{ 'STH' };
  boom "missing SELECT::STH! call select() before fetch()" unless $sth;

  my $dbh = $self->{ 'SELECT' }{ 'DBH' };
  boom "missing SELECT::DBH! call select() before fetch()" unless $dbh;

  my @data = $sth->fetchrow_array();
  if( ! @data )
    {
    $self->{ 'SELECT' }{ 'EOD' } = 1; # end of data
    return undef;
    }

  my $select_fields = $self->{ 'SELECT' }{ 'FIELDS' };
  
  my %data;
  my $c = 0;
  for my $field ( @$select_fields )
    {
    $data{ $field } = $data[ $c ];
    $c++;
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
  if( $profile and ! $profile->has_root_access() and $profile->check_access( 967 ) )
    {
    boom "E_ACCESS: user group 967 has global write restriction";
    }
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'INSERT', $table );
    }

  my $table_des = describe_table( $table );
  
  return 1 if $table_des->is_virtual();

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

  de_log_debug( "sql: ".__PACKAGE__."::insert:\n---BEGIN SQL---\n$sql_stmt\n---SQL BIND ARGS---\n@values\n---SQL BIND HASH---\n".Dumper( $data )."\n---END SQL---" );

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
  if( $profile and ! $profile->has_root_access() and $profile->check_access( 967 ) )
    {
    boom "E_ACCESS: user group 967 has global write restriction";
    }
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'UPDATE', $table );
    }

  my @where;
  my @bind;

  my $table_des = describe_table( $table );
  my $db_table  = $table_des->get_db_table_name();

  return 1 if $table_des->is_virtual();

  $opts = { 'BIND' => $opts } if ref( $opts ) eq 'ARRAY'; # directly BIND values

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
    
    # TODO: FIXME: stupid :)
    $value = 0 if $field_type_name ne 'CHAR' and $field_type_name ne 'WIDELINK' and $value == 0;
    
    $columns .= "$field=?,";
    push @values, $value;
    }
  chop( $columns );

  # FIXME: different databases support vastly differs as well :(
  #push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  #delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };

  # TODO: support for _UPDATE_* fields

  my $where_clause;
  if( @where )
    {
    $where_clause = join( "\n    AND ", @where );
    }

  my $db_table = $table_des->get_db_table_name();
  my $sql_stmt = "UPDATE\n    $db_table\nSET\n    $columns\nWHERE\n    $where_clause";

  de_log_debug( "sql: ".__PACKAGE__."::update:\n---BEGIN SQL---\n$sql_stmt\n---SQL BIND VALUES---\n@values\n---SQL BIND ARGS---\n@bind\n---SQL BIND HASH---\n".Dumper( $data )."\n---END SQL---" );

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

sub delete
{
  my $self  = shift;
  my $table = shift;
  my $where = shift;
  my $opts  = shift;

  $self->__reshape( $table );

  my $profile = $self->__get_profile();
  if( $profile and ! $profile->has_root_access() and $profile->check_access( 967 ) )
    {
    boom "E_ACCESS: user group 967 has global write restriction";
    }
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'DELETE', $table );
    }

  my @where;
  my @bind;

  my $table_des = describe_table( $table );
  my $db_table  = $table_des->get_db_table_name();

  return 1 if $table_des->is_virtual();

  $opts = { 'BIND' => $opts } if ref( $opts ) eq 'ARRAY'; # directly BIND values

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
    # do not allow delete without WHERE!
    boom "WHERE clause is mandatory for DELETE";
    }

  push @where, $self->__get_row_access_where_list( $table, 'OWNER', 'DELETE' );

  # FIXME: different databases support vastly differs as well :(
  #push @where, keys %{ $self->{ 'SELECT' }{ 'RESOLVE_WHERE' } };
  #delete $self->{ 'SELECT' }{ 'RESOLVE_WHERE' };

  # TODO: support for _DELETE_* fields

  my $where_clause;
  if( @where )
    {
    $where_clause = join( "\n    AND ", @where );
    }

  my $db_table = $table_des->get_db_table_name();
  my $sql_stmt = "DELETE FROM\n    $db_table\nWHERE\n    $where_clause";

  de_log_debug( "sql: ".__PACKAGE__."::update:\n---BEGIN SQL---\n$sql_stmt\n---SQL BIND ARGS---\n@bind\n---END SQL---" );

#print STDERR Dumper( '-' x 72, __PACKAGE__ . "::DELETE: table [$table] sql/where/bind", $sql_stmt, $where_clause, \@bind, $self );

  my $dbh = dsn_get_dbh_by_table( $table );
  my $rc = $dbh->do( $sql_stmt, {}, ( @bind ) );

  return $rc ? $rc : 0;
}

#-----------------------------------------------------------------------------

sub delete_id
{
  my $self  = shift;
  my $table = shift;
  my $id    = shift;
  my $opts  = shift;

  return $self->delete( $table, '_ID = ?', { BIND => [ $id ] } );
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

  my $table_des = describe_table( $table );
  my $db_seq    = $table_des->get_db_sequence_name();
  my $dsn       = $table_des->get_dsn_name();

  return 1 if $table_des->is_virtual();
  
  my $new_id = $self->get_next_sequence( $db_seq, $dsn );
  de_log_debug( "debug: get_next_table_id: for table [$table] new val [$new_id]" );
  return $new_id;
}

#--- helpers -----------------------------------------------------------------

sub read_first1_hashref
{
  my $self  = shift;
  my $table = shift;
  my $where = shift;
  my $opts  = shift; 

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
  my $opts  = shift || {}; 

  return $self->read_first1_hashref( $table, '._ID = ?', { %$opts, BIND => [ $id ] } );
}

sub count
{
  my $self  = shift;
  my $table = shift;
  my $where = shift;
  my $opts  = shift; 

  $self->select( $table, 'COUNT(*)', $where, $opts );
  my $data = $self->fetch();
  $self->finish();
  
  return $data->{ 'COUNT(*)' };
}


### EOF ######################################################################
1;
