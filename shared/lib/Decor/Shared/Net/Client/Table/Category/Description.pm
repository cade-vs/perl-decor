##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client::Table::Category::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub client
{
  my $self = shift;
  
  return $self->{ ':CLIENT_OBJECT' };
}

sub describe
{
  my $self = shift;
  
  return $self->client()->describe( @_ );
}

sub allows
{
  my $self = shift;
  
  my $oper = uc shift;

  return 0 if    ( exists $self->{ 'DENY'  }{ $oper } and $self->{ 'DENY'  }{ $oper } ) 
              or ( exists $self->{ 'DENY'  }{ 'ALL' } and $self->{ 'DENY'  }{ 'ALL' } );

  return 1 if    ( exists $self->{ 'GRANT' }{ $oper } and $self->{ 'GRANT' }{ $oper } ) 
              or ( exists $self->{ 'GRANT' }{ 'ALL' } and $self->{ 'GRANT' }{ 'ALL' } );
  
  return 0;
}

### EOF ######################################################################
1;
