##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Table::Category::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub describe
{
  boom "describe must be reimplemented in the subclass";
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

### EOF ######################################################################
1;
