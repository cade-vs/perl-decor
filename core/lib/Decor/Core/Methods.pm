##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Methods;
use strict;

use Data::Tools;
use Exception::Sink;

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::DB::Record;
use Decor::Core::Shop;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                find_user_by_name
                find_user_by_id
                create_group
                create_user
                attach_user_groups
                detach_user_groups
                detach_all_user_groups
                set_user_pass
                
                update_backlink_count
                update_backlink_sum
                
                rec_sort_fields_n
                reorder_date_time

                record_exists_by_fields
                record_exists_by_fields_add_error
                check_unique_field_set
                
                read_dict
                );

# note: the result record will be locked
sub find_user_by_name
{
  my $name = shift;
  
  my $rec = new Decor::Core::DB::Record;
  return $rec if $rec->select_first1( 'DE_USERS', 'NAME = ?', { BIND => [ $name ], LOCK => 1 } );
  return undef;
}

# note: the result record will be locked
sub find_user_by_id
{
  my $id = shift;
  
  my $rec = new Decor::Core::DB::Record;
  return $rec if $rec->load( 'DE_USERS', $id, { LOCK => 1 } );
  return undef;
}

#  my $group_rec = create_group( $new_group_name );
#  note: on return $group_rec is already saved into DB
sub create_group
{
  my $name   = shift;
  
  return undef unless $name; # cannot be really '0' :)

  # create private group record
  my $grp_rec = new Decor::Core::DB::Record;
  $grp_rec->create( 'DE_GROUPS' );
  $grp_rec->write( 
                    NAME      => $name, 
                  );
  $grp_rec->save();
  
  return $grp_rec;
}

#  my $user_rec = create_user( $new_user_name, $password, $primary_group_id, $groups_arrayref );
#  note: on execution, private group for the new user will be created
#  note: on return $user_rec is already saved into DB
#  note: $primary_group_id can be undef to generate new group on the fly
#  note: created user is ACTIVE by default, check DE_USERS
sub create_user
{
  my $name   = shift;
  my $pass   = shift;
  my $pigrp  = shift; # primary group, or undef to use the private instead
  my $groups = shift || [];
  
  # create private group record
  my $pvt_grp_rec = create_group( $name );

  # create user record
  my $user_rec = new Decor::Core::DB::Record;
  $user_rec->create( 'DE_USERS' );
  
  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    NAME      => $name, 
                    ACTIVE    => 1,
                  );

  # setup password if specified, otherwise user will not be able to login
  if( $pass ne '' )
    {
    my $user_salt     = create_random_id( 128 );
    my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

    $user_rec->write( 
                      PASS      => $user_pass_hex,
                      PASS_SALT => $user_salt,
                    );
    }
  
  $pigrp ||= $pvt_grp_rec->id();
  
  $user_rec->write( 'PRIMARY_GROUP' => $pigrp             );
  $user_rec->write( 'PRIVATE_GROUP' => $pvt_grp_rec->id() );
  
  $user_rec->save();

  # attach given groups
  attach_user_groups( $user_rec, [ 999, $pvt_grp_rec->id(), $pigrp, @$groups ] );
  
  return $user_rec;
}

sub attach_user_groups
{
  my $user   = shift; # user id or user rec
  my $groups = shift || [];
  
  my $user_id = ref $user ? $user->id() : $user;

  my $dio = new Decor::Core::DB::IO;
  my @groups = list_uniq( @$groups );

  my $agc = 0;
  for my $group ( @groups )
    {
    # check if already attached
    next if $dio->read_first1_hashref( 'DE_USER_GROUP_MAP', 'USR = ? AND GRP = ?', { BIND => [ $user_id, $group ] } );
    # attach group
    my $rc = $dio->insert( 'DE_USER_GROUP_MAP', { USR => $user_id, GRP => $group } );
    $agc++ if $rc;
    }
  
  return $agc;
}

sub detach_user_groups
{
  my $user   = shift; # user id or user rec
  my $groups = shift || [];
  
  my $user_id = ref $user ? $user->id() : $user;

  boom "user_id must be positive, non-zero number" unless $user_id > 0;

  my $dio = new Decor::Core::DB::IO;
  my @groups = list_uniq( @$groups );

  my $dgc = 0;
  for my $group ( @groups )
    {
    boom "group_id must be positive, non-zero number" unless $group > 0;
    my $rc = $dio->delete( 'DE_USER_GROUP_MAP', 'USR = ? AND GRP = ?', { BIND => [ $user_id, $group ] } );
    $dgc++ if $rc;
    }
  
  return $dgc;
}

sub detach_all_user_groups
{
  my $user   = shift; # user id or user rec
  my $groups = shift || [];
  
  my $user_id = ref $user ? $user->id() : $user;

  boom "user_id must be positive, non-zero number" unless $user_id > 0;

  my $dio = new Decor::Core::DB::IO;
  my $rc = $dio->delete( 'DE_USER_GROUP_MAP', 'USR = ?', { BIND => [ $user_id ] } );
  
  return $rc;
}

sub set_user_pass
{
  my $user = shift;
  my $pass = shift;
  
  my $user_rec = ref( $user ) eq 'Decor::Core::DB::Record::User' ? $user : find_user_by_name( $user );
  
  return undef unless $user_rec;
  return undef unless $pass ne '';

  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    PASS      => $user_pass_hex,
                    PASS_SALT => $user_salt,
                  );
  
  return 1;                
}

# usage: backlink table, backlink field --> table/rec, field, <id>
sub update_backlink_count
{
  my $backlink_table = shift;
  my $backlink_field = shift;
  my $table_rec      = shift;
  my $field          = shift;
  my $id             = shift;
  my $tune_count     = shift || 0;

  $id = $table_rec->id() if ref( $table_rec );
  boom "missing 5th arg [ID]" unless $id > 0;
  
  my $io = new Decor::Core::DB::IO;
  my $count = $io->count( $backlink_table, "$backlink_field = ?", { BIND => [ $id ] } );
  $count += $tune_count;
  
  if( ref( $table_rec ) )
    {
    $table_rec->write( $field => $count );
    }
  else
    {
    $io->update_id( $table_rec, { $field => $count }, $id );
    }  
}

# usage: backlink table, backlink field --> table/rec, field, <id>
sub update_backlink_sum
{
  my $backlink_table = shift;
  my $backlink_field = shift;
  my $backlink_sum   = uc shift;
  my $table_rec      = shift;
  my $field          = shift;
  my $id             = shift;
  my $tune_sum       = shift || 0;

  $id = $table_rec->id() if ref( $table_rec );
  boom "missing 5th arg [ID]" unless $id > 0;
  
  my $io = new Decor::Core::DB::IO;
  my $sum = $io->sum( $backlink_table, $backlink_sum, "$backlink_field = ?", { BIND => [ $id ] } );
  $sum += $tune_sum;
  
  if( ref( $table_rec ) )
    {
    $table_rec->write( $field => $sum );
    }
  else
    {
    $io->update_id( $table_rec, { $field => $sum }, $id );
    }  
}

sub rec_sort_fields_n
{
  my $rec = shift;

  my @values;
  push( @values, $rec->read( $_ ) ) for @_;

  @values = sort { $a <=> $b } @values;

  $rec->write( $_ => shift( @values ) ) for @_;

  return 1;
}

*reorder_date_time = *rec_sort_fields_n;

sub record_exists_by_fields
{
  my $rec = shift;

  boom "error: method: check_unique_field_set(): arg 0 must be a record object" unless ref $rec;
  
  my @where = '_ID <> ?';
  my @bind  = id $rec;

  for my $f ( @_ )
    {
    push @where, "$f = ?";
    push @bind,  $rec->read( $f );
    }
  my $where = join ' AND ', @where;

  my $db = io_new();
  
  return $db->read_field( $rec->table(), '_ID', $where, { BIND => \@bind } );
}

sub record_exists_by_fields_add_error
{
  my $rec    = shift;
  my @fields = @_;
  
  return undef unless record_exists_by_fields( $rec, @fields );
  
  $rec->method_add_field_error( $_, 'Already exists!' ) for @fields;
  
  return 1;
}

sub check_unique_field_set
{
  my $rec = shift;

  boom "error: method: check_unique_field_set(): arg 0 must be a record object" unless ref $rec;

  my $id = record_exists_by_fields( $rec, @_ );
  return 0 if $id < 1 or $id == $rec->id();

  my $err = "Same data record already exists!";
  $rec->method_add_field_error( $_, $err ) for @_;
  
  $rec->method_add_error( $err )
}

sub read_dict
{
  my $table  = shift;
  my $key    = shift;
  my $fields = shift;

  my %data;
  
  my $io = io_new();
  
  $io->select( $table, $fields );
  while( my $hr = $io->fetch() )
    {
    $data{ $hr->{ $key } } = $hr;
    }
  $io->finish();
  
  return \%data;  
}

### EOF ######################################################################
1;
