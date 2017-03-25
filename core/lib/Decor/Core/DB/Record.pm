##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record;
use strict;

use parent 'Decor::Core::DB';
use Exception::Sink;

use Decor::Shared::Types;
use Decor::Shared::Utils;
use Decor::Core::DSN;
use Decor::Core::Describe;
use Decor::Core::DB::IO;
use Decor::Core::Code;

##############################################################################

# TODO: add profiles check and support
# TODO: add resolve checks for inter cross-DSN links
# TODO: add resolve READONLY/WRITE support for read/write
# TODO: check profile/taint mode logic, taint or get-profile should be first?

##############################################################################

sub __init
{
  my $self = shift;

  $self->{ 'DB::IO' } = new Decor::Core::DB::IO;
  $self->reset();

  1;
}

sub reset
{
  my $self = shift;

  delete $self->{ 'BASE_TABLE'         };
  delete $self->{ 'BASE_ID'            };
  delete $self->{ 'RECORD_DATA'        };
  delete $self->{ 'RECORD_DATA_DB'     };
  delete $self->{ 'RECORD_MODIFIED'    };
  delete $self->{ 'RECORD_INSERT'      };
  delete $self->{ 'RECORD_IMODS'       };
  delete $self->{ 'RECORD_DATA_UPDATE' };

  return 1;
}

sub set_read_only
{
  my $self = shift;

  my $state = shift;

  $state = 1 if $state < 1; # once set read-only, record cannot be brought back to read-write state

  $self->{ 'READ_ONLY' } = $state;

  return $state;
}

sub is_read_only
{
  my $self = shift;

  return $self->{ 'READ_ONLY' };
}

sub is_empty
{
  my $self = shift;

  return 0 if exists $self->{ 'BASE_TABLE' } and exists $self->{ 'RECORD_DATA' };
  return 1;
}

sub set_profile
{
  my $self  = shift;

  $self->SUPER::set_profile( @_ );
  $self->{ 'DB::IO' }->set_profile( @_ ); # sync taint mode

  return 1;
}

sub set_profile_locked
{
  my $self  = shift;

  $self->SUPER::set_profile_locked( @_ );
  $self->{ 'DB::IO' }->set_profile_locked( @_ ); # sync taint mode

  return 1;
}

sub taint_mode_on
{
  my $self  = shift;

  $self->SUPER::taint_mode_on( @_ );
  $self->{ 'DB::IO' }->taint_mode_on( @_ ); # sync taint mode

  return 1;
}

sub taint_mode_off
{
  my $self  = shift;

  $self->SUPER::taint_mode_off( @_ );
  $self->{ 'DB::IO' }->taint_mode_off( @_ ); # sync taint mode

  return 1;
}

sub create
{
  my $self  = shift;

  my $table = uc shift;
  my $id    =    shift;

  boom "invalid TABLE name [$table]" unless des_exists( $table );
  boom "invalid ID [$id]"            unless $id eq '' or de_check_id( $id );

  $self->check_if_locked_to( $table );

  # read-only records cannot create read-write objects
  my $ro = $self->is_read_only();

  $self->reset();

  $self->set_read_only( $ro ) if $ro > 0;

  $self->{ 'BASE_TABLE' } = $table;

  my $new_id = $self->__create_empty_data( $table, $id );

  $self->{ 'BASE_ID'    } = $new_id;

  return $new_id;
}

sub create_read_only
{
  my $self  = shift;

  my $table = uc shift;

  $self->set_read_only();
  return $self->create( $table );
}

sub load
{
  my $self  = shift;

  my $table = uc shift;
  my $id    = shift;
  my $opt   = shift || {};

  boom "invalid TABLE name [$table]" unless des_exists( $table );
  de_check_id_boom( $id, "invalid ID [$id]" );
  # TODO: check if opt is hashref

  $self->check_if_locked_to( $table, $id );

  $self->reset();

  # FIXME: try to load record first
  my %data = map { $_ => '' } @{ des_table_get_fields_list( $table ) };

  my $dbio = $self->{ 'DB::IO' };

  # $dbio is already taint-ed, so will not read restricted record
  my $data = $dbio->read_first1_by_id_hashref( $table, $id, { LOCK => $opt->{ 'LOCK' } } );

  if( ! $data )
    {
    # FIXME: need more here?
    return undef;
    }

  $self->{ 'BASE_TABLE' } = $table;
  $self->{ 'BASE_ID'    } = $id;

  $self->{ 'RECORD_DATA'    }{ $table }{ $id } = \%data;
  $self->{ 'RECORD_DATA_DB' }{ $table }{ $id } = { %data }; # copy, used for profile checks

  return $id;
}

sub lock_to_table
{
  my $self  = shift;

  boom "cannot lock-to-table empty record (missing table name)" unless $self->{ 'BASE_TABLE' };

  $self->{ 'LOCKED_TO_TABLE' } = $self->{ 'BASE_TABLE' };
  1;
}

sub lock_to_record
{
  my $self  = shift;

  boom "cannot lock-to-record empty record (missing table name)" unless $self->{ 'BASE_TABLE' };
  boom "cannot lock-to-record record without id"                 unless $self->{ 'BASE_ID'    };

  $self->{ 'LOCKED_TO_TABLE' } = $self->{ 'BASE_TABLE' };
  $self->{ 'LOCKED_TO_ID'    } = $self->{ 'BASE_ID'    };
  1;
}

sub check_if_locked_to
{
  my $self  = shift;

  my $table = uc shift;
  my $id    = shift;

  my $locked_to_table = $self->{ 'LOCKED_TO_TABLE' };
  my $locked_to_id    = $self->{ 'LOCKED_TO_ID'    };

  return 1 unless $locked_to_table;

  boom "record is locked to table [$locked_to_table] and cannot be changed to [$table]" unless $locked_to_table eq $table;

  return 1 if $id eq '';
  return 1 unless $locked_to_id ne '';

  boom "record is locked to table:id [$locked_to_table:$locked_to_id] and cannot be changed to [$table:$id]" unless $locked_to_id > 0 and $locked_to_id == $id;

  1;
}

sub id
{
  my $self = shift;

  return ( exists $self->{ 'BASE_ID'    } and $self->{ 'BASE_ID'    } ) ? $self->{ 'BASE_ID'    } : undef;
}

sub table
{
  my $self = shift;

  return ( exists $self->{ 'BASE_TABLE' } and $self->{ 'BASE_TABLE' } ) ? $self->{ 'BASE_TABLE' } : undef;
}

#-----------------------------------------------------------------------------

sub __get_new_id
{
  my $self = shift;

  my $table = $self->table();
  boom "cannot get new ID for record without attached TABLE" unless $table;

  if( $self->is_read_only() )
    {
    return - ( 100 + $self->{ 'READ_ONLY_ID_COUNTER' }++ );
    }
  else
    {
    my $dbio = $self->{ 'DB::IO' };
    return $dbio->get_next_table_id( $table );
    }
}

sub __create_empty_data
{
  my $self = shift;

  my $table  = shift;
  my $new_id = shift;

####  my $dbio = $self->{ 'DB::IO' };

  if( ! $self->is_read_only() and $new_id <= 0 )
    {
###    $new_id = $dbio->get_next_table_id( $table );
    $new_id = $self->__get_new_id();
    }

  my $profile = $self->__get_profile();
  if( $profile and $self->taint_mode_get( 'TABLE' ) )
    {
    $profile->check_access_table_boom( 'INSERT', $table );
    }

  my %data; # FIXME: populate with defaults

  my $tdes = describe_table( $table );
  for my $field ( @{ $tdes->get_fields_list() } )
    {
    my $fdes = $tdes->get_field_des( $field );
    $data{ $field } = type_default( $fdes->{ 'TYPE' }{ 'NAME' } );
    }

  $data{ '_ID' } = $new_id;

  if( $profile and $self->taint_mode_get( 'ROWS' ) )
    {
    # TODO: fill default values for _OPER_*
    }

  $self->{ 'RECORD_MODIFIED' }++;
  $self->{ 'RECORD_INSERT' }{ $table }{ $new_id }++;
  $self->{ 'RECORD_IMODS'  }{ $table }{ $new_id }++;
  $self->{ 'RECORD_DATA'   }{ $table }{ $new_id } = \%data;

  return $new_id;

}

# this module handles high-level, structured system/staged database io

sub __get_base_table_fields
{
  my $self = shift;

  boom "record is empty, cannot be read/written" if $self->is_empty();

  my $base_table = $self->{ 'BASE_TABLE' };

  my $des = describe_table( $base_table );
  return $des->get_fields_list();
}

sub read
{
  my $self = shift;

  boom "record is empty, cannot be read" if $self->is_empty();

  my @res;
  for my $field ( @_ )
    {
    my ( $dst_table, $dst_field, $dst_id ) = $self->__resolve_field( $field );

    push @res, $dst_table ? $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field } : undef;
    }

  return wantarray ? @res : shift( @res );
}

sub read_all
{
  my $self = shift;

  return $self->read( @{ $self->__get_base_table_fields() } );
}

sub read_hash
{
  my $self = shift;

  boom "record is empty, cannot be read" if $self->is_empty();

  my @res;
  for my $field ( @_ )
    {
    my ( $dst_table, $dst_field, $dst_id ) = $self->__resolve_field( $field );

    push @res, $field;
    push @res, $dst_table ? $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field } : undef;
    }

  return wantarray ? @res : { @res };
}

sub read_hash_all
{
  my $self = shift;

  return $self->read_hash( @{ $self->__get_base_table_fields() } );
}

sub write
{
  my $self = shift;

  boom "record is empty, cannot be written"     if $self->is_empty();
  boom "record is read_only, cannot be written" if $self->is_read_only() > 1;

  my $profile = $self->__get_profile();

  my $mods_count = 0; # modifications count
  my @data = @_;
  while( @data )
    {
    my $field = shift( @data );
    my $value = shift( @data );

    my ( $dst_table, $dst_field, $dst_id ) = $self->__resolve_field( $field, { WRITE => 1 } );

#use Data::Dumper;
#print Dumper( '--------', $self );

    if( $profile and $self->taint_mode_get( 'FIELDS' ) )
      {
      my $oper = $self->{ 'RECORD_INSERT' }{ $dst_table }{ $dst_id } ? 'INSERT' : 'UPDATE';
#use Data::Dumper;
#print Dumper( '--------oper: ', $oper, $dst_table, $dst_field );
      $profile->check_access_table_field_boom( $oper, $dst_table, $dst_field );
      }

    # FIXME: check for number values
    next if $self->{ 'RECORD_DATA' }{ $dst_table }{ $dst_id }{ $dst_field } eq $value;
    # FIXME: IMPORTANT: check for DB data read for update records!

    $mods_count++;

    # mark the record and specific fields as modified
    $self->{ 'RECORD_MODIFIED'    }++;
    $self->{ 'RECORD_IMODS'       }{ $dst_table }{ $dst_id }++;
    $self->{ 'RECORD_DATA'        }{ $dst_table }{ $dst_id }{ $dst_field } = $value;
    $self->{ 'RECORD_DATA_UPDATE' }{ $dst_table }{ $dst_id }{ $dst_field } = $value;
    }

  return $mods_count;
}

sub __resolve_field
{
  my $self = shift;

  my $field = uc shift;
  my $opt   = shift;

  my $base_table = $self->{ 'BASE_TABLE' };
  my $base_id    = $self->{ 'BASE_ID'    };

  my $write_resolve = $opt->{ 'WRITE' };

  if( $field !~ /\./ ) # if no path was given, i.e. field.field.field
    {
    boom "cannot resolve table/field [$base_table/$field]" unless des_exists( $base_table, $field );
    return ( $base_table, $field, $base_id );
    }

  my @fields = split /\./, $field;

  my $current_table = $base_table;
  my $current_field = shift @fields;
  my $current_id    = $base_id;
  while(4)
    {
#print "debug: record resolve table [$current_table] field [$current_field] id [$current_id] fields [@fields]\n";
    my $field_des = describe_table_field( $current_table, $current_field );

    if( @fields == 0 )
      {
      return ( $current_table, $current_field, $current_id );
      }

    my $linked_table = $field_des->{ 'LINKED_TABLE' };
    boom "cannot resolve table/field [$current_table/$current_field] invalid linked table [$linked_table]" unless des_exists( $linked_table );
    my $next_id = $self->{ 'RECORD_DATA'  }{ $current_table }{ $current_id }{ $current_field };

    if( $next_id == 0 )
      {
      return () unless $write_resolve;
      # __create_empty_data() will check for INSERT access
      # FIXME: TODO: check if ID already given inside the link field
      $next_id = $self->__create_empty_data( $linked_table );

      my $profile = $self->__get_profile();
      if( $profile )
        {
        my $current_insert = $self->{ 'RECORD_INSERT' }{ $current_table }{ $current_id };
        if( $self->taint_mode_get( 'FIELDS' ) )
          {
          my $oper = $current_insert ? 'INSERT' : 'UPDATE';
          $profile->check_access_table_field_boom( $oper, $current_table, $current_field );
          }
        if( $self->taint_mode_get( 'ROWS' ) )
          {
          # check if owner(s) is ok
          $profile->check_access_row_boom( 'OWNER',  $current_table, $self );
          # check for UPDATE access, but only for non-insert records
          $profile->check_access_row_boom( 'UPDATE', $current_table, $self ) unless $current_insert;
          }
        }

      $self->{ 'RECORD_IMODS'       }{ $current_table }{ $current_id }++;
      $self->{ 'RECORD_DATA'        }{ $current_table }{ $current_id }{ $current_field } = $next_id;
      $self->{ 'RECORD_DATA_UPDATE' }{ $current_table }{ $current_id }{ $current_field } = $next_id;

      $current_table = $linked_table;
      $current_id    = $next_id;
      $current_field = shift @fields;
      }
    else
      {
      if( ! exists $self->{ 'RECORD_DATA'  }{ $linked_table }{ $next_id } )
        {
        my $dbio = $self->{ 'DB::IO' };
        my $data = $dbio->read_first1_by_id_hashref( $linked_table, $next_id );

        $self->{ 'RECORD_MODIFIED' }++;
        $self->{ 'RECORD_IMODS'    }{ $linked_table }{ $next_id }++;
        $self->{ 'RECORD_DATA'     }{ $linked_table }{ $next_id } = $data;
        $self->{ 'RECORD_DATA_DB'  }{ $linked_table }{ $next_id } = { %$data }; # copy, used for profile checks
        }
      $current_table = $linked_table;
      $current_id    = $next_id;
      $current_field = shift @fields;
      }
    }
}

sub save
{
  my $self = shift;

  return 1 if $self->is_read_only();

  return undef unless $self->{ 'RECORD_MODIFIED' } > 0;
  my $dbio = $self->{ 'DB::IO' };

  my $profile = $self->__get_profile();

  my @tables = keys( %{ $self->{ 'RECORD_DATA' } } );
  for my $table ( @tables )
    {
    my @ids = keys( %{ $self->{ 'RECORD_IMODS'  }{ $table } } );
    for my $id ( @ids )
      {
      next unless $self->{ 'RECORD_IMODS' }{ $table }{ $id };
      delete $self->{ 'RECORD_IMODS' }{ $table }{ $id };

      next if $id == 0; # skip base records

      if( $self->{ 'RECORD_INSERT' }{ $table }{ $id } )
        {
        if( $profile )
          {
          if( $self->taint_mode_get( 'TABLE' ) )
            {
            $profile->check_access_table_boom( 'INSERT', $table );
            }
          }

        my $data = $self->{ 'RECORD_DATA' }{ $table }{ $id };
        my $new_id = $dbio->insert( $table, $data );

        delete $self->{ 'RECORD_INSERT'      }{ $table }{ $id };
        delete $self->{ 'RECORD_DATA_UPDATE' }{ $table }{ $id };
        $self->{ 'RECORD_DATA_DB' }{ $table }{ $id } = { %$data }; # copy
        }
      else
        {
        if( $profile )
          {
          if( $self->taint_mode_get( 'TABLE' ) )
            {
            $profile->check_access_table_boom( 'UPDATE', $table );
            }

          if( $self->taint_mode_get( 'ROWS' ) )
            {
            $profile->check_access_row_boom( 'OWNER',  $table, $self );
            $profile->check_access_row_boom( 'UPDATE', $table, $self );
            }
          }

        my $data = $self->{ 'RECORD_DATA_UPDATE' }{ $table }{ $id };
        my $ok_id = $dbio->update_id( $table, $data, $id );
        delete $self->{ 'RECORD_DATA_UPDATE' }{ $table }{ $id };
        }
      }
    }
  $self->{ 'RECORD_MODIFIED' } = 0;

  return 1;
}

#-----------------------------------------------------------------------------

sub select
{
  my $self = shift;

  my $table = uc shift;
  my $where = shift;
  my $opt   = shift;

  $self->reset();
  my $dbio = $self->{ 'SELECT::DB::IO' } = new Decor::Core::DB::IO;

  # TODO: copy taint mode to $dbio

  my $fields = des_table_get_fields_list( $table );
  return $dbio->select( $table, $fields, $where, $opt );
}

sub next
{
  my $self  = shift;

  my $dbio = $self->{ 'SELECT::DB::IO' };
  boom "cannot call select() before next()" unless $dbio;

  # TODO: add at least base_table, even no data found at all

  $self->reset();

  $self->{ 'SELECT::DB::IO' } = $dbio;
  my $table = $dbio->{ 'SELECT' }{ 'BASE_TABLE' };

  my $data = $dbio->fetch();

  return undef unless $data;

  my $id = $data->{ '_ID' };

  $self->check_if_locked_to( $table, $id );

  $self->{ 'BASE_TABLE' } = $table;
  $self->{ 'BASE_ID'    } = $id;

  $self->{ 'RECORD_DATA'    }{ $table }{ $id } = $data;
  $self->{ 'RECORD_DATA_DB' }{ $table }{ $id } = { %$data }; # copy, used for profile checks

  return $id;
}

sub finish
{
  my $self = shift;

  my $dbio = $self->{ 'SELECT::DB::IO' };

  $dbio->finish();

  delete $self->{ 'SELECT::DB::IO' };

  1;
}

sub select_first1
{
  my $self = shift;

  $self->select( @_ );
  my $res = $self->next();
  $self->finish();

  return defined $res ? $res : undef;
}

#-----------------------------------------------------------------------------

sub delete
{
  my $self = shift;

  my $db_io = $self->{ 'DB::IO' };
  
  my $rc = $db_io->delete_id( $self->table(), $self->id() );
  
  $self->reset() if $rc;

  return $rc;
}

#-----------------------------------------------------------------------------

sub commit
{
  my $self = shift;

  dsn_commit();
}

sub savepoint
{
  my $self    = shift;
  my $sp_name = shift;

  my $des = describe_table( $self->table() );
  my $dsn = $des->get_dsn_name();
  dsn_savepoint( $sp_name, $dsn );
}

sub rollback
{
  my $self = shift;

  dsn_rollback();
}

sub rollback_to_savepoint
{
  my $self    = shift;
  my $sp_name = shift;

  my $des = describe_table( $self->table() );
  my $dsn = $des->get_dsn_name();
  dsn_savepoint_to_savepoint( $sp_name, $dsn );
}

### METHODS ##################################################################

sub method
{
  my $self = shift;
  my $name = shift;

  return undef unless de_code_exists( 'tables', $self->table(), $name );

  return de_code_exec( 'tables', $self->table(), $name, $self, @_ );
}

sub reset_errors
{
  my $self = shift;

  delete $self->{ 'METHOD:ERRORS' };
}

sub method_add_error
{
  my $self = shift;

  push @{ $self->{ 'METHOD:ERRORS' }{ '*' } }, @_;
}

sub method_add_field_error
{
  my $self = shift;
  my $name = uc shift;

  push @{ $self->{ 'METHOD:ERRORS' }{ $name } }, @_;
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
