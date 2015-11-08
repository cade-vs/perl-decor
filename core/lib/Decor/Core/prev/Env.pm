##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Env;
use strict;

use Data::Lock qw( dlock );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                rs_version
                rs_root
                rs_debug
                rs_set_debug

                );

### PRIVATE ##################################################################

my %RS_CONFIG;

__init_ev();

sub __init_ev
{
  %RS_CONFIG = ();
  
  $RS_CONFIG{ 'VERSION' } = 1.00;
  $RS_CONFIG{ 'ROOT'    } = $ENV{ 'RECON_ROOT' } || '/usr/local/recon';
  unshift @INC, $RS_CONFIG{ 'ROOT' } . '/core/lib';
}

### PUBLIC ###################################################################

sub rs_version
{
  return $RS_CONFIG{ 'VERSION' };
}

sub rs_root
{
  return $RS_CONFIG{ 'ROOT' };
}

sub rs_set_debug
{
  my $level  = shift;
  $RS_CONFIG{ 'DEBUG' } = $level;
  return $level;
}

sub rs_debug
{
  return $RS_CONFIG{ 'DEBUG' };
}

### EOF ######################################################################
1;
