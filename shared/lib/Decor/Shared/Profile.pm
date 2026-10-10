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
##  shared profile: set of user groups and grant/deny access tree evaluation,
##  the same on all sides (core, remote/client, web)
##
##  no DB, no description loading here, descriptions are given to allows()
##  core subclass adds DB user groups loading and out-of-band access rules
##
##############################################################################
package Decor::Shared::Profile;
use strict;

use Hash::Util qw( lock_ref_keys );
use Exception::Sink;

use Data::Dumper;

use Decor::Shared::Utils;

##############################################################################

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;

  my $self = {};
  bless $self, $class;

  de_obj_add_debug_info( $self );
  $self->__init();

  return $self;
}

sub __init
{
  my $self = shift;

  $self->{ 'GROUPS'        } = {};
  $self->{ 'PRIMARY_GROUP' } = 0;
  $self->{ 'CACHE'         } = {};
  $self->{ 'VAR'           } = {};

  lock_ref_keys( $self );
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

    # skip ROOT (1), NOBODY (900) and GUEST (901) groups, they must never appear inside profile
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
    de_check_id_boom( $group, "invalid group id [$group] expected number" );
    $group = int( $group );
    delete $self->{ 'GROUPS' }{ $group };
    }
}

sub get_groups
{
  my $self = shift;

  return keys %{ $self->{ 'GROUPS' } };
}

sub get_groups_hr
{
  my $self = shift;

  return { %{ $self->{ 'GROUPS' } } };
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

  $self->{ 'CACHE' } = {};
  $self->{ 'GROUPS' }{ 1 } = 1;
}

sub disable_root_access
{
  my $self = shift;

  $self->{ 'CACHE' } = {};
  delete $self->{ 'GROUPS' }{ 1 };
}

sub has_root_access
{
  my $self = shift;

  return exists $self->{ 'GROUPS' }{ 1 } ? 1 : 0;
}

### GROUP CHECKS #############################################################

sub check_access
{
  my $self = shift;

  return 1 if $self->has_root_access();

  my $group = int( $_[0] );
  return 0 if $group == 0;

  return exists $self->{ 'GROUPS' }{ $group } ? $self->{ 'GROUPS' }{ $group } : 0;
}

sub check_access_boom
{
  my $self = shift;

  die "E_ACCESS: [@_] denied" unless $self->check_access( @_ );
}

### ACCESS TREES #############################################################

# allows( $des, $oper ) checks description item (table '@', field, do, action)
# grant/deny trees: DENY first, then GRANT, default deny
sub allows
{
  my $self = shift;
  my $des  = shift;
  my $oper = uc shift;

  $des = $des->{ '@' } if ref( $des ) and exists $des->{ '@' }; # whole table description given, check its self item

  return 0 if $self->match_tree( $des->{ 'DENY'  }, $oper );
  return 1 if $self->match_tree( $des->{ 'GRANT' }, $oper );
  return 0;
}

# match_tree( $tree, $oper ) true if current groups match the access tree
# for the operation, tree format as built by description loader:
#   OPER => group | [ [ group, group ], [ '!group' ], ... ]
sub match_tree
{
  my $self = shift;
  my $tree = shift;
  my $oper = shift;

# print STDERR "profile access exists check: [$oper]\n" . Dumper( $tree );  

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
        next if exists $groups->{ 909 };
        my $grp = int( $1 );
# print STDERR "profile access ! check: [$grp]\n";  
        boom "group [$group] in grant|deny policy set for operation [$oper] is equal to zero [$grp] all groups must not be zero" if $grp == 0;
        $c++ if ! exists $groups->{ $grp } or ! ( $groups->{ $grp } > 0 );
        }
      else
        {
        my $grp = int( $group );
# print STDERR "profile access   check: [$grp]\n";  
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
