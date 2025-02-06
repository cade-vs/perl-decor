##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Description::Table::Category;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub is_self_category
{
  return undef;
}

sub describe
{
  my $self = shift;

  return $self->get_top_des()->describe( @_ );
}

sub get_attr
{
  my $self = shift;
  my @path = @_;

  my $attr = pop @path;
  
  boom "missing ATTRIBUTE NAME argument" unless $attr;
  
  while( @path )
    {
    my $full_attr = join '.', @path, $attr;
    return $self->{ $full_attr } if exists $self->{ $full_attr };
    pop @path;
    }

  return undef unless exists $self->{ $attr };
    
  return $self->{ $attr };
}

sub get_top_des
{
  my $self = shift;

  boom "missing top/super des callback" unless $self->{ ':SUPER_CB' };
  return $self->{ ':SUPER_CB' }->();
}

sub get_self_des
{
  my $self = shift;

  return $self->get_top_des()->{ '@' };
}

sub table
{
  my $self = shift;
  
  return $self->{ 'TABLE' };
}

sub name
{
  my $self = shift;
  
  return $self->{ 'NAME' };
}

sub allows
{
  my $self = shift;
  
  my $oper    = uc shift;
  my $profile = shift; # not used here, only inside core

  return 0 if    ( exists $self->{ 'DENY'  }{ $oper } and $self->{ 'DENY'  }{ $oper } ) 
              or ( exists $self->{ 'DENY'  }{ 'ALL' } and $self->{ 'DENY'  }{ 'ALL' } );

  return 1 if    ( exists $self->{ 'GRANT' }{ $oper } and $self->{ 'GRANT' }{ $oper } ) 
              or ( exists $self->{ 'GRANT' }{ 'ALL' } and $self->{ 'GRANT' }{ 'ALL' } );
  
  return 0;
}

### EOF ######################################################################
1;
