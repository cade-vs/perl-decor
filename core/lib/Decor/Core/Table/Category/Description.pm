##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Category::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub describe
{
  my $self = shift;
  
  return describe_table( @_ );
}

### EOF ######################################################################
1;
