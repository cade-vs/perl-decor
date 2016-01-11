##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB;
use strict;

use parent 'Decor::Core::Base';
use Exception::Sink;

use Decor::Core::Utils;

##############################################################################

sub __init
{
  my $self = shift;
  
  1;
}

sub set_profile
{
  my $self    = shift;
  my $profile = shift;

  boom "PROFILE is locked and cannot be changed" if $self->{ 'PROFILE_LOCKED' };
  
  de_check_ref( $profile, 'Decor::Core::Profile', "invalid or missing PROFILE reference, got [$profile]" );
  
  $self->{ 'PROFILE' } = $profile;
}

sub set_profile_locked
{
  my $self    = shift;

  $self->set_profile( @_ );
  # lock the used profile, no changes to profile is further allowed
  $self->{ 'PROFILE_LOCKED' } = 1;
}

### EOF ######################################################################
1;
