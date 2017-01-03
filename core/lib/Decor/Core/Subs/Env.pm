##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Subs;
use strict;
use Exception::Sink;
use Data::Tools;
use Decor::Core::Log;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                subs_reset_current_all
                
                subs_set_current_user
                subs_get_current_user
                subs_lock_current_user

                subs_get_current_user_id

                subs_set_current_session
                subs_get_current_session
                subs_lock_current_session
                
                subs_set_current_profile
                subs_get_current_profile
                subs_lock_current_profile

                );

##############################################################################

# Decor::Core::DB::Record's
my $USER;
my $SESSION;
# Decor::Core::Profile
my $PROFILE;

my $USER_LOCKED;
my $SESSION_LOCKED;
my $PROFILE_LOCKED;

##############################################################################

sub subs_reset_current_all
{
  $USER    = undef;
  $SESSION = undef;
  $PROFILE = undef;

  $USER_LOCKED    = undef;
  $SESSION_LOCKED = undef;
  $PROFILE_LOCKED = undef;

  return 1;
}

#--- USER --------------------------------------------------------------------

sub subs_set_current_user
{
  my $user_rec = shift;
  
  de_check_ref( $user_rec, 'Decor::Core::DB::Record', "invalid user object, expected [Decor::Core::DB::Record]" );
  boom "cannot replace currently locked user" if $USER_LOCKED;
  
  $USER = $user_rec;
  return $USER;
};

sub subs_get_current_user
{
  boom "requesting current user but it is empty" unless $USER;
  
  return $USER;
};

sub subs_lock_current_user
{
  my $user_rec = shift;
  
  subs_set_current_user( $user_rec ) if $user_rec;

  boom "requesting lock on current user but it is empty" unless $USER;
  $USER_LOCKED = 1;
  
  return $USER;
};

sub subs_get_current_user_id
{
  boom "requesting current user ID but it is empty" unless $USER;
  
  return $USER->id();
};

#--- SESSION -----------------------------------------------------------------

sub subs_set_current_session
{
  my $session_rec = shift;
  
  de_check_ref( $session_rec, 'Decor::Core::DB::Record', "invalid session object, expected [Decor::Core::DB::Record]" );
  boom "cannot replace currently locked session" if $SESSION_LOCKED;
  
  $SESSION = $session_rec;
  return $SESSION;
};

sub subs_get_current_session
{
  boom "requesting current session but it is empty" unless $SESSION;
  
  return $SESSION;
};

sub subs_lock_current_session
{
  my $session_rec = shift;
  
  subs_set_current_session( $session_rec ) if $session_rec;

  boom "requesting lock on current session but it is empty" unless $SESSION;
  $SESSION_LOCKED = 1;
  
  return $SESSION;
};

#--- PROFILE -----------------------------------------------------------------

sub subs_set_current_profile
{
  my $profile_rec = shift;
  
  de_check_ref( $profile_rec, 'Decor::Core::Profile', "invalid session object, expected [Decor::Core::Profile]" );
  boom "cannot replace currently locked profile" if $PROFILE_LOCKED;
  
  $PROFILE = $profile_rec;
  return $PROFILE;
};

sub subs_get_current_profile
{
  boom "requesting current profile but it is empty" unless $PROFILE;
  
  return $PROFILE;
};

sub subs_lock_current_profile
{
  my $profile_rec = shift;
  
  subs_set_current_profile( $profile_rec ) if $profile_rec;

  boom "requesting lock on current profile but it is empty" unless $PROFILE;
  $PROFILE_LOCKED = 1;
  
  return $PROFILE;
};

### EOF ######################################################################
1;
