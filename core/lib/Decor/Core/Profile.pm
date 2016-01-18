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

use Decor::Core::Utils;

##############################################################################

sub __init
{
  my $self = shift;
  
  $self->{ 'GROUPS' } = {};
  
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

  return $self->{ 'GROUPS' };
}

sub clear_groups
{
  my $self = shift;

  $self->{ 'ACCESS_CACHE' } = {};
  $self->{ 'GROUPS' } = {};
}

### ACCESS CHECKS ############################################################

sub access
{
  my $self = shift;

  my $group = lc $_[0];
  
  return $self->{ 'GROUPS' }{ $group } if exists $self->{ 'GROUPS' }{ $group };
}

sub access_table
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];

  return $self->access_table_field( $oper, $table, '@' );
}

sub access_table_field
{
  my $self = shift;

  my $oper  = uc $_[0];
  my $table = uc $_[1];
  my $field = uc $_[2];
  
  if( exists $self->{ 'ACCESS_CACHE' }{ $field }{ $oper } )
    {
    return $self->{ 'ACCESS_CACHE' }{ $field }{ $oper };
    }
  
  #my $des = $self->{ 'STAGE' }{ 'CACHE_STORAGE' }{ 'TABLE_DES' }{ $table };
  my $des = $self->{ 'STAGE' }->describe_table( $table );

#print "profile access des\n" . Dumper( $des );  
  
  if( $self->__check_access_tree( $oper, $des->{ $field }{ 'DENY'  } ) )
    {
    $self->{ 'ACCESS_CACHE' }{ $field }{ $oper } = 0;
    return 0;
    }
    
  if( $self->__check_access_tree( $oper, $des->{ $field }{ 'ALLOW' } ) )
    {
    $self->{ 'ACCESS_CACHE' }{ $field }{ $oper } = 1;
    return 1;
    }
  
  $self->{ 'ACCESS_CACHE' }{ $field }{ $oper } = 0;
  return 0;
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
