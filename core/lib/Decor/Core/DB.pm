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
use Data::Lock qw( dlock );
use Hash::Util qw( lock_ref_keys );

use Decor::Core::Utils;

my %TAINT_MODES = (
                  ROWS   => 1,
                  TABLE  => 1,
                  FIELDS => 1,
                  );
dlock \%TAINT_MODES;
                  
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
  $self->{ 'TAINT'   } = {};
}

sub set_profile_locked
{
  my $self    = shift;

  $self->set_profile( @_ );
  # lock the used profile, no changes to profile is further allowed
  $self->{ 'PROFILE_LOCKED' } = 1;
}

sub profile_lock
{
  my $self    = shift;
  
  $self->{ 'PROFILE_LOCKED' } = 1 if $self->{ 'PROFILE' };
  return $self->{ 'PROFILE_LOCKED' };
}

sub __get_profile
{
  my $self    = shift;

  return exists $self->{ 'PROFILE' } ? $self->{ 'PROFILE' } : undef;
}

sub taint_mode_on
{
  my $self    = shift;

  boom "cannot enable taint mode without profile" unless $self->__get_profile();

  for( @_ )
    {
    my $mode = uc $_;
    if( $mode eq 'NONE' )
      {
      $self->{ 'TAINT' } = {};
      }
    elsif( $mode eq 'ALL' )
      {
      $self->{ 'TAINT' } = { %TAINT_MODES };
      }
    else
      {  
      boom "invalid mode [$mode]" unless exists $TAINT_MODES{ $mode };
      $self->{ 'TAINT' }{ $mode } = 1;
      }
    }

  return 1;
}

sub taint_mode_enable_all
{
  my $self    = shift;
  
  $self->taint_mode_on( 'ALL' );
}

sub taint_mode_off
{
  my $self    = shift;

  for my $mode ( @_ )
    {
    $mode = uc $mode;
    if( $mode eq 'ALL' )
      {
      $self->{ 'TAINT' } = {};
      }
    else
      {  
      boom "invalid mode [$mode]" unless exists $TAINT_MODES{ $mode };
      $self->{ 'TAINT' }{ $mode } = 0;
      }
    }

  return 1;
}

sub taint_mode_get
{
  my $self = shift;
  
  my $mode = uc shift;
  boom "invalid mode [$mode]" unless exists $TAINT_MODES{ $mode };
  return $self->{ 'TAINT' }{ $mode };
}

sub taint_mode_get_all_enabled
{
  my $self = shift;

  return map { $self->{ 'TAINT' }{ $_ } ? $_ : () } keys %{ $self->{ 'TAINT' } };
}

### EOF ######################################################################
1;
