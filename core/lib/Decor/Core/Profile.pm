##############################################################################
##
##  Decor application machinery core
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  core profile: shared profile + DB user groups loading, out-of-band access
##  rules, table/field/category access by name and row level access
##
##############################################################################
package Decor::Core::Profile;
use strict;

use parent 'Decor::Shared::Profile';
use Exception::Sink;

use Data::Dumper;

use Decor::Shared::Utils;
use Decor::Core::Log;
use Decor::Shared::Describe;
use Decor::Core::DB::IO;

##############################################################################

# TODO: expire cache if description access is modified

### USER DB LOAD DATA ########################################################

sub set_groups_from_user
{
  my $self = shift;

  $self->clear_groups();
  $self->add_groups_from_user( @_  );
}

sub add_groups_from_user
{
  my $self = shift;
  my $user = shift;

  my $user_id;

  if( ref( $user ) eq 'Decor::Core::DB::Record::User' and ! $user->is_empty() and $user->table() eq 'DE_USERS' )
    {
    # record with loaded record from DE_USERS
    $user_id = $user->id();
    }
  elsif( $user =~ /^\d+$/ )
    {
    # user id (number)
    $user_id = $user;
    }
  elsif( ref( $user ) eq '' )
    {
    # plain scalar
    my $dbio = new Decor::Core::DB::IO;
    # TODO: move to Decor::Core::DB::Utils, read single hr or field
    my $user_hr = $dbio->read_first1_hashref( 'DE_USERS', 'NAME = ?', { BIND => [ $user ] } );
    boom "unknown user [$user]" unless $user_hr;
    $user_id = $user_hr->{ '_ID' };
    }
  else
    {
    boom "invalid or unknown user reference [$user]";
    }

  my $cnt;
  # TODO: move to Decor::Core::DB::Utils, read list of columns
  my $dbio = new Decor::Core::DB::IO;
  $dbio->select( 'DE_USER_GROUP_MAP', '*', 'USR = ?', { BIND => [ $user_id ] } );
  while( my $hr = $dbio->fetch() )
    {
    $self->add_groups( $hr->{ 'GRP' } );
    $cnt++;
    }
  $dbio->finish();

  de_log_debug2( "debug: profile: user [$user] has groups added: " . join( ', ', sort { $a <=> $b } $self->get_groups() ) );

  return $cnt;
}

### ACCESS TREES #############################################################

# out-of-band rules before the grant/deny trees, must match the client side
# mapping in Decor::Core::Subs::__replace_grant_deny():
# root has access to all, 966 allows READ, CROSS and ACCESS globally,
# 967 denies INSERT, UPDATE, DELETE and EXECUTE
sub allows
{
  my $self = shift;
  my $des  = shift;
  my $oper = uc shift;

  return 1 if $self->has_root_access();

  return 1 if $oper =~ /^(READ|CROSS|ACCESS)$/            and exists $self->{ 'GROUPS' }{ 966 };
  return 0 if $oper =~ /^(INSERT|UPDATE|DELETE|EXECUTE)$/ and exists $self->{ 'GROUPS' }{ 967 };

  return $self->SUPER::allows( $des, $oper );
}

### ACCESS CHECKS BY NAME ####################################################

sub check_access_table
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  return $self->check_access_table_field( $oper, $table, '@' );
}

sub check_access_table_boom
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  my $res = $self->check_access_table( @_ );
  boom "E_ACCESS: [$oper] denied for table [$table] res [$res]" unless $res;

  return $res;
}

sub check_access_table_field
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $field = uc $_[2];

#print STDERR "check_access_table_field: [@_]\n";

  return $self->check_access_table_category( $oper, $table, 'FIELD', $field );
}

sub check_access_table_field_boom
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $field = uc $_[2];

  my $res = $self->check_access_table_field( @_ );
  die "E_ACCESS: [$oper] denied for table [$table] field [$field] res [$res]" unless $res;

  return $res;
}

sub check_access_table_category
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $cat   = uc $_[2]; # category
  my $item  = uc $_[3]; # category item

#print STDERR "check_access_table_category: [@_]\n";

  # TCO == table category oper
  my $cache = $self->{ 'CACHE' }{ 'ACCESS' }{ 'TCO' }{ $table }{ $cat }{ $item } ||= {};

  if( exists $cache->{ $oper } )
    {
    $self->{ 'VAR' }{ 'CACHE_HITS' }++;
    return $cache->{ $oper };
    }

  my $cdes = des_category_des( $table, $cat, $item ); # booms for unknown table/item

  return $cache->{ $oper } = $self->allows( $cdes, $oper ) ? 1 : 0;
}

### ROW ACCESS ###############################################################

# FIXME: server-only, to be moved out of the profile into a core function
# same rules as the SQL row filter in Decor::Core::DB::IO::__get_row_access_where_list():
# _OWNER* fields are always checked, then _<OPER>* fields, each group of fields
# passes if any field matches (or there are no such fields), 961 ignores ownership
sub check_access_row
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $dsrc  =    $_[2]; # data source, hashref or record object

  return 1 if $self->check_access( 961 ); # ignore ownership globally
  return 0 if $oper ne 'READ' and exists $self->{ 'GROUPS' }{ 967 };

  my @opers = ( 'OWNER' );
  push @opers, $oper unless $oper eq 'OWNER' or ( $oper eq 'READ' and exists $self->{ 'GROUPS' }{ 966 } ); # 966 reads all rows

  my $fields = des_fields_list( $table );
  for my $op ( @opers )
    {
    my $sccnt = 0; # security checks count
    my $ok;
    for my $field ( @$fields )
      {
      next unless $field =~ /^_${op}([_0-9][A-Z_0-9]*)?$/; # _OWNER, _OWNER2, _OWNER_X but not _OWNERSHIP, same as in Loader/Table.pm and DB/IO.pm

      $sccnt++;
      my $grp = ref( $dsrc ) eq 'HASH' ? $dsrc->{ $field } : $dsrc->read( $field );
      if( $self->check_access( $grp ) )
        {
        $ok = 1;
        last;
        }
      }
    return 0 if $sccnt > 0 and ! $ok; # fields exist for this operation but none matches
    }

  return 1; # also when no security checks are performed at all
}

sub check_access_row_boom
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  my $res = $self->check_access_row( @_ );
  die "E_ACCESS: row access [$oper] denied for table [$table] res [$res]" unless $res;

  return $res;
}

### EOF ######################################################################
1;
