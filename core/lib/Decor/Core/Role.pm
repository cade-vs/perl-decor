##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Role;
use strict;

use parent 'Decor::Core::Base';
use Exception::Sink;

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
  
  for my $group ( @groups )
    {
    $group = lc $group;
    de_check_name_boom( $group, "invalid group name [$group]" );
    $self->{ 'GROUPS' }{ $group } = 1; # fixme: group classes/types
    }
}

sub del_groups
{
  my $self = shift;

  my @groups = @_;
  
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

  my $table = uc $_[0];
  my $right = uc $_[1];
  
#  my $des = $self->get_stage()->describe_table( $table );
  my $des = $self->{ 'STAGE' }{ 'TABLE_DES_CACHE' }{ $table };
  
  #my $table_des = $des->get_des();

  my $group = $des->{ '@' }{ $right };

#use Data::Dumper;
#print "+++++++++++++++$table $group $des\n" . Dumper( $table_des );
  
  return 1 if exists $self->{ 'GROUPS' }{ $group } and $self->{ 'GROUPS' }{ $group } > 0;
  return 0;
}

### EOF ######################################################################
1;
