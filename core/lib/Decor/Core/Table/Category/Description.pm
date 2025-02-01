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

use Exception::Sink;

use Decor::Shared::Table::Category::Description;

use parent 'Decor::Shared::Table::Category::Description';

##############################################################################

sub allows
{
  boom "core description allows() is not implemented yet!";
}

### EOF ######################################################################
1;
