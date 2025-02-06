##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Description::Table::Category;
use strict;

use Exception::Sink;

use parent 'Decor::Shared::Description::Table::Category';

##############################################################################

sub allows
{
  boom "core description allows() is not implemented yet!";
}

### EOF ######################################################################
1;
