##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
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

sub get_groups
{
  my $self   = shift;

  my $io = new Decor::Core::DB::IO;
  return $io->read_all_fields( 'DE_USER_GROUP_MAP', 'GRP', 'USR = ?', { BIND => [ $self->id() ] } );
}

sub has_group
{
  my $self   = shift;
  
  return exists $self->get_groups()->{ shift() };
}

sub is_active
{
  my $self   = shift;

  return $self->read( 'ACTIVE' ) > 0;
}

### EOF ######################################################################
1;
