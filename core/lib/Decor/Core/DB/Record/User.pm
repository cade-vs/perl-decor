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

use Crypt::Argon2 qw( argon2id_pass argon2_verify );

use Decor::Core::DB::Record;
use Exception::Sink;
use Data::Tools;

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

sub is_disabled
{
  my $self   = shift;

  return $self->read( 'DISABLED' ) > 0;
}

sub set_password
{
  my $self   = shift;
  
  my $pass   = shift;
  
  # Hash a password
  my $salt    = create_random_id( 16 );
  my $encoded = argon2id_pass( $pass, $salt,  32, '32M', 1, 32 );
  
  # PASS_SALT not needed in the case of using argon2
  $self->write( 'PASS' => $encoded, 'PASS_SALT' => $salt );
  
  return 1;
}

sub verify_password
{
  my $self   = shift;

  my $pass   = shift;
  
  my $encoded = $self->read( 'PASS' );
  
  return argon2_verify( $encoded, $pass );
}

### EOF ######################################################################
1;
