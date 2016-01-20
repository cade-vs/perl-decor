##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Base;
use strict;

use Hash::Util qw( lock_ref_keys );
use Data::Tools;

use Decor::Core::Utils;
use Exception::Sink;

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my %args = @_;
  
  my $stage = $args{ 'STAGE' };
  de_check_ref( $stage, 'Decor::Core::Stage', "invalid or missing STAGE reference, got [$stage]" );
  
  my $cache = $stage->__get_cache_storage( $class );
  
  my $self = {
             STAGE => $stage,
             CACHE => $cache,
             };
  bless $self, $class;
  
  de_obj_add_debug_info( $self );
  $self->__init();
  return $self;
}

sub __init
{
  0;
}

sub __lock_self_keys
{
  my $self = shift;

  for my $key ( @_ )
    {
    next if exists $self->{ $key };
    $self->{ $key } = undef;
    }
  lock_ref_keys( $self );  
}

sub get_stage
{
  my $self = shift;
  
  return $self->{ 'STAGE' };
}

### EOF ######################################################################
1;
