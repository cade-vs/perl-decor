##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
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

use Decor::Core::Describe;
use Decor::Core::Utils;

##############################################################################

# TODO: expire cache if description acces is modified
# TODO: check if correct lc/uc for groups/opers is used

##############################################################################

sub __init
{
  my $self = shift;
  
  $self->{ 'GROUPS'       } = {};
  $self->{ 'ACCESS_CACHE' } = {};
  $self->{ 'VAR'          } = {};
  
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
  
  $self->{ 'ACCESS_CACHE' } = {};
  for my $group ( @groups )
    {
    $group = lc $group;
    de_check_name_boom( $group, "invalid group name [$group]" );
    $self->{ 'GROUPS' }{ $group } = 1; # fixme: group classes/types
    }
}

sub remove_groups
{
  my $self = shift;

  my @groups = @_;
  
  $self->{ 'ACCESS_CACHE' } = {};
  for my $group ( @groups )
    {
    if( $group eq '*' )
      {
      $self->clear_groups();
      return;
      }
    $group = lc $group;
    de_check_name_boom( $group, "invalid group name [$group]" );
    delete $self->{ 'GROUPS' }{ $group };
    }
}

sub get_groups
{
  my $self = shift;

  return keys %{ $self->{ 'GROUPS' } };
}

sub clear_groups
{
  my $self = shift;

  $self->{ 'ACCESS_CACHE' } = {};
  $self->{ 'GROUPS'       } = {};
}

### ACCESS CHECKS ############################################################

sub check_access
{
  my $self = shift;

  my $group = lc $_[0];
  
  return $self->{ 'GROUPS' }{ $group } if exists $self->{ 'GROUPS' }{ $group };
}

sub check_access_table
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  return $self->check_access_table_field( $oper, $table, '@' );
}

sub check_access_table_boom
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  my $res = $self->check_access_table( @_ );
  boom "EACCESS: [$oper] denied for table [$table] res [$res]" unless $res;
  
  return $res;
}

sub check_access_table_field
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $field = uc $_[2];

  $self->{ 'ACCESS_CACHE' }{ 'TFO' }{ $table }{ $field } ||= {};
  my $cache = $self->{ 'ACCESS_CACHE' }{ 'TFO' }{ $table }{ $field };

  if( $cache and exists $cache->{ $oper } )
    {
    $self->{ 'VAR' }{ 'CACHE_HITS' }++;
    return $cache->{ $oper };
    }
  
  my $fdes = describe_table_field( $table, $field );

  if( $self->__check_access_tree( $oper, $fdes->{ 'DENY'  } ) )
    {
    $cache->{ $oper } = 0;
    return 0;
    }
    
  if( $self->__check_access_tree( $oper, $fdes->{ 'ALLOW' } ) )
    {
    $cache->{ $oper } = 1;
    return 1;
    }
  
  $cache->{ $oper } = 0;
  return 0;
}

sub check_access_table_field_boom
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $field = uc $_[2];

  my $res = $self->access_table_field( @_ );
  boom "EACCESS: [$oper] denied for table [$table] field [$field] res [$res]" unless $res;
  
  return $res;
}

sub check_access_row
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $dsrc  = uc $_[2]; # data source, hashref or record object

  my $fields = des_table_get_fields_list( $table );
  my $scc = 0; # security checks count
  for my $field ( @$fields )
    {
    next unless $field =~ /^_${oper}(_[A-Z_0-9]+)?/;

    my $scc++;
    my $grp = ref( $dsrc ) eq 'HASH' ? $dsrc->{ $field } : $dsrc->read( $field );
    my $res = $self->check_access(  );
    return 1 if $res;
    }
  
  return $scc > 0 ? 0 : 1; # return 1/allow if no security checks are performed at all
}

sub check_access_row_boom
{
  my $self = shift;

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
  
  for my $sets ( @{ $tree->{ $oper } } )
    {
    my $c = 0;
    for my $group ( @$sets )
      {
      if( $group =~ /^!(.+)$/ )
        {
        my $group = $1;
#print "profile access ! check: [$group]\n";  
        $c++ if ! exists $self->{ 'GROUPS' }{ $group } or ! ( $self->{ 'GROUPS' }{ $group } > 0 );
        }
      else
        {
#print "profile access   check: [$group]\n";  
        $c++ if   exists $self->{ 'GROUPS' }{ $group } and  ( $self->{ 'GROUPS' }{ $group } > 0 );
        }  
      }  
    return 1 if $c == @$sets;
    }
  return 0;
}

### EOF ######################################################################
1;
