##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Env;
use strict;

use Data::Lock qw( dlock );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_version
                de_root
                de_debug
                de_set_debug

                );

### PRIVATE ##################################################################

my %DE_CONFIG;

__init_ev();

sub __init_ev
{
  %DE_CONFIG = ();
  
  $DE_CONFIG{ 'VERSION' } = 1.00;
  $DE_CONFIG{ 'ROOT'    } = $ENV{ 'DECOR_ROOT' } || '/usr/local/decor';
  unshift @INC, $DE_CONFIG{ 'ROOT' } . '/core/lib';
}

### PUBLIC ###################################################################

sub de_version
{
  return $DE_CONFIG{ 'VERSION' };
}

sub de_root
{
  return $DE_CONFIG{ 'ROOT' };
}

sub de_set_debug
{
  my $level  = shift;
  $DE_CONFIG{ 'DEBUG' } = $level;
  return $level;
}

sub de_debug
{
  return $DE_CONFIG{ 'DEBUG' };
}

### EOF ######################################################################
1;
