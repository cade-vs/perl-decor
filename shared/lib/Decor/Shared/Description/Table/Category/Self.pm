##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Description::Table::Category::Self;
use strict;

use parent 'Decor::Shared::Description::Table::Category';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub is_self_category
{
  return 1;
}

sub get_table_name
{
  my $self  =    shift;
  
  return $self->{ 'TABLE' };
}

sub get_label
{
  my $self  =    shift;
  
  return $self->{ 'LABEL' };
}



### EOF ######################################################################
1;
