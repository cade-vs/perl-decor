##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client::Table::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub get_fields_list_by_oper
{
  my $self = shift;
  
  my $oper = uc shift;
  
  return $self->{ 'CACHE' }{ 'FIELDS_LIST_BY_OPER' }{ $oper } if exists $self->{ 'CACHE' }{ 'FIELDS_LIST_BY_OPER' }{ $oper };
  
  my @f;
  
  for my $f ( keys %{ $self->{ 'FIELD' } } )
    {
    next unless $self->{ 'FIELD' }{ $f }{ 'GRANT' }{ $oper } or $self->{ 'FIELD' }{ $f }{ 'GRANT' }{ 'ALL' };
    next if     $self->{ 'FIELD' }{ $f }{ 'DENY'  }{ $oper } or $self->{ 'FIELD' }{ $f }{ 'DENY'  }{ 'ALL' };
    push @f, $f;
    }

  @f = sort { $self->{ 'FIELD' }{ $a }{ '_ORDER' } <=> $self->{ 'FIELD' }{ $b }{ '_ORDER' } } @f;

  $self->{ 'CACHE' }{ 'FIELDS_LIST_BY_OPER' }{ $oper } = \@f;
  
  return \@f;
}

### EOF ######################################################################
1;
