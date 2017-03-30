##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record::Session;
use strict;

use Decor::Core::DB::Record;
use Exception::Sink;

use parent 'Decor::Core::DB::Record';

### DE_USERS api interface ###################################################

sub is_active
{
  my $self   = shift;

  return $self->read( 'ACTIVE' ) > 0;
}

### EOF ######################################################################
1;
