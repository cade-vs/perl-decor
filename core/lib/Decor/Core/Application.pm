##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Application;
use strict;

use Decor::Core::Env;
use Decor::Core::Utils;

my %DE_APP_DEFAULTS = (
                      ROOT => '',
                      );

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  my $self = {
  
             };
  bless $self, $class;
  
  de_obj_add_debug_info( $self );  
  return $self;
}


### EOF ######################################################################
1;
