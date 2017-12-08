##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Profile;
use strict;

use parent 'Decor::Core::Base';
use Exception::Sink;

use Data::Dumper;

use Decor::Shared::Utils;
use Decor::Core::Log;
use Decor::Core::Describe;

##############################################################################

# TODO: expire cache if description acces is modified

##############################################################################

sub __init
{
  my $self = shift;
  
  $self->{ 'GROUPS'        } = {};
  $self->{ 'PRIMARY_GROUP' } = 0;
  $self->{ 'CACHE'         } = {};
  $self->{ 'VAR'           } = {};
  
  $self->__lock_self_keys();
  1;
}

### MANAGEMENT ###############################################################

sub set_groups
{
  my $self = shift;
  
  $self->clear_groups();
  $self->add_groups( @_  );
}

sub add_groups
{
  my $self = shift;

  my @groups = @_;
  
  $self->{ 'CACHE' } = {};
  for my $group ( @groups )
    {
    de_check_id_boom( $group, "invalid group id [$group] expected number" );
    $group = int( $group );

    # skip ROOT and NOBODY groups, the must never appear inside profile
    next if $group == 1 or $group == 900 or $group == 901;
    
    $self->{ 'GROUPS' }{ $group } = 1; # fixme: group classes/types
    }
}

sub remove_groups
{
  my $self = shift;

  my @groups = @_;
  
  $self->{ 'CACHE' } = {};
  for my $group ( @groups )
    {
    if( $group eq '*' )
      {
      $self->clear_groups();
      return;
      }
    de_check_name_boom( $group, "invalid group id [$group] expected number" );
    $group = int( $group );
    delete $self->{ 'GROUPS' }{ $group };
    }
}

sub get_groups
{
  my $self = shift;

  return keys %{ $self->{ 'GROUPS' } };
}

sub get_groups_string
{
  my $self = shift;

  return $self->{ 'CACHE' }{ 'GET_GROUPS_STRING_RES' } if $self->{ 'CACHE' }{ 'GET_GROUPS_STRING_RES' };

  my @groups = $self->get_groups();
  @groups = sort { $a <=> $b } @groups;
  return $self->{ 'CACHE' }{ 'GET_GROUPS_STRING_RES' } = join ',', @groups;
}

sub clear_groups
{
  my $self = shift;

  $self->{ 'CACHE'  } = {};
  $self->{ 'GROUPS' } = {};
}

### PRIMARY GROUP ############################################################

sub set_primary_group
{
  my $self = shift;
  my $group = shift || 0;

  de_check_id_boom( $group, "invalid group id [$group] expected number" );
  $group = int( $group );

  $self->{ 'PRIMARY_GROUP' } = $group;
  
  return $group;
}

sub get_primary_group
{
  my $self = shift;
  
  return $self->{ 'PRIMARY_GROUP' } || 0;
}

### ROOT MANAGEMENT ##########################################################

sub enable_root_access
{
  my $self = shift;

  $self->{ 'GROUPS' }{ 1 } = 1;
}

sub disable_root_access
{
  my $self = shift;

  delete $self->{ 'GROUPS' }{ 1 };
}

sub has_root_access
{
  my $self = shift;

  return exists $self->{ 'GROUPS' }{ 1 } ? 1 : 0;
}

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

  de_log_debug( "debug: USER [$user] GROUPS ADDED: " . join( ',', $self->get_groups() ) );

  return $cnt;  
}

### ACCESS CHECKS ############################################################

sub check_access
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $group = int( $_[0] );
  return 0 if $group == 0;
  
  return $self->{ 'GROUPS' }{ $group } if exists $self->{ 'GROUPS' }{ $group };
}

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
  boom "EACCESS: [$oper] denied for table [$table] res [$res]" unless $res;
  
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
  boom "EACCESS: [$oper] denied for table [$table] field [$field] res [$res]" unless $res;
  
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

  if( $cache and exists $cache->{ $oper } )
    {
    $self->{ 'VAR' }{ 'CACHE_HITS' }++;
    return $cache->{ $oper };
    }
  
  my $tdes = describe_table( $table );
  my $cdes = $tdes->get_category_des( $cat, $item );

  if( $self->__check_access_tree( $oper, $cdes->{ 'DENY'  } ) )
    {
#print STDERR "check_access_table_category: deny denied\n";
    $cache->{ $oper } = 0;
    return 0;
    }
    
  if( $self->__check_access_tree( $oper, $cdes->{ 'GRANT' } ) )
    {
#print STDERR "check_access_table_category: grant granted\n";
    $cache->{ $oper } = 1;
    return 1;
    }
  
#print STDERR "check_access_table_category: default denied\n";
  $cache->{ $oper } = 0;
  return 0;
}

sub check_access_row
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $dsrc  =    $_[2]; # data source, hashref or record object

  my $fields = des_table_get_fields_list( $table );
  my $sccnt = 0; # security checks count
#print STDERR "--------------------------------check access row [$oper] [$table] [$dsrc] [---] ($sccnt)\n";
  for my $field ( @$fields )
    {
    next unless $field =~ /^_${oper}(_[A-Z_0-9]+)?/;

    $sccnt++;
    my $grp = ref( $dsrc ) eq 'HASH' ? $dsrc->{ $field } : $dsrc->read( $field );
    my $res = $self->check_access( $grp );

#print STDERR "--------------------------------check access row [$oper] [$table] [$dsrc] [$field]=>[$grp]==OK?[$res] SCCNT($sccnt)\n";

    return 1 if $res;
    }
  
  return $sccnt > 0 ? 0 : 1; # return 1/allow if no security checks are performed at all
}

sub check_access_row_boom
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $dsrc  = uc $_[2]; # data source, hashref or record object

  my $res = $self->check_access_row( @_ );
  boom "EACCESS: row access [$oper] denied for table [$table] res [$res]" unless $res;
  
  return $res;
}

sub __check_access_tree
{
  my $self = shift;

  my $oper = shift;
  my $tree = shift;

#print "profile access exists check: [$oper]\n" . Dumper( $tree );  

  return 0 unless exists $tree->{ $oper };

  my $groups = $self->{ 'GROUPS' };
  
  if( ! ref( $tree->{ $oper } ) and $tree->{ $oper } )
    {
    # quick check if there is only one group in the policy
    return $groups->{ $tree->{ $oper } } > 0 ? 1 : 0;
    }
  
  for my $sets ( @{ $tree->{ $oper } } )
    {
    my $c = 0;
    for my $group ( @$sets )
      {
      if( $group =~ /^!\s*([0-9]+)$/ )
        {
        my $grp = int( $1 );
#print "profile access ! check: [$grp]\n";  
        boom "group [$group] in grant|deny policy set for operation [$oper] is equal to zero [$grp] all groups must not be zero" if $grp == 0;
        $c++ if ! exists $groups->{ $grp } or ! ( $groups->{ $grp } > 0 );
        }
      else
        {
        my $grp = int( $group );
#print "profile access   check: [$grp]\n";  
        boom "group [$group] in grant|deny policy set for operation [$oper] is equal to zero [$grp] all groups must not be zero" if $grp == 0;
        $c++ if   exists $groups->{ $grp } and  ( $groups->{ $grp } > 0 );
        }  
      }  
    return 1 if $c == @$sets;
    }
  return 0;
}


### EOF ######################################################################
1;
