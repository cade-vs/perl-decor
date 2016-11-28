##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client::Table::Field::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub get_attr
{
  my $self = shift;
  my @path = @_;
  
  my $attr = pop @path;
  
  boom "missing ATTRIBUTE NAME argument" unless $attr;
  
  while( @path )
    {
    my $full_attr = join '.', @path, $attr;
    
print STDERR "++++++++++++++++++++++++++++[$full_attr]\n";
    
    return $self->{ $full_attr } if exists $self->{ $full_attr };
    pop @path;
    }

  boom "ATTRIBUTE [$attr] does not exist" unless exists $self->{ $attr };
    
  return $self->{ $attr };
}

### EOF ######################################################################
1;
