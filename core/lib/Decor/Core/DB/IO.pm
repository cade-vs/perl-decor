##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO;
use strict;

use parent 'Decor::Core::DB';
use Exception::Sink;

use Decor::Core::Utils;

##############################################################################

sub __init
{
  my $self = shift;
  
  1;
}

# this module handles low-level database io sql statements and data

### EOF ######################################################################
1;
