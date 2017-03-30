##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record::User;
use strict;

use Decor::Core::DB::Record;
use Exception::Sink;

use parent 'Decor::Core::DB::Record';

### DE_USERS api interface ###################################################

sub get_primary_group
{
  my $self   = shift;

  return $self->read( 'PRIMARY_GROUP' );
}

sub get_private_group
{
  my $self   = shift;

  return $self->read( 'PRIVATE_GROUP' );
}

sub is_active
{
  my $self   = shift;

  return $self->read( 'ACTIVE' ) > 0;
}

### EOF ######################################################################
1;
