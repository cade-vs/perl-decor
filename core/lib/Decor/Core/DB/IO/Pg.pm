##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO::Pg;
use strict;

use Exception::Sink;

use parent 'Decor::Core::DB::IO';


### PostgreSQL Specifics #####################################################

sub __init
{
  my $self = shift;
  
  1;
}

### EOF ######################################################################
1;
