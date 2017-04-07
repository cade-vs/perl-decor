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

sub allows
{
  my $self = shift;
  
  my $oper = uc shift;

print STDERR Dumper( $self->{ 'GRANT' } );
my $f = $self->{ 'NAME' };
print STDERR "================allow=========$oper================pre[$f]\n";

  return 0 if    ( exists $self->{ 'DENY'  }{ $oper } and $self->{ 'DENY'  }{ $oper } ) 
              or ( exists $self->{ 'DENY'  }{ 'ALL' } and $self->{ 'DENY'  }{ 'ALL' } );

print STDERR "================mid===========$oper================pre[$f]\n";
              
  return 1 if    ( exists $self->{ 'GRANT' }{ $oper } and $self->{ 'GRANT' }{ $oper } ) 
              or ( exists $self->{ 'GRANT' }{ 'ALL' } and $self->{ 'GRANT' }{ 'ALL' } );
  
print STDERR "==============================$oper================DENIED[$f]\n\n";
  return 0;
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
