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

# use Data::Lock qw( dlock );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_version
                de_root
                de_debug
                de_debug_set
                de_debug_inc
                de_debug_off

                );

### PRIVATE ##################################################################

my $VERSION = '1.00';
my $ROOT    = $ENV{ 'DECOR_ROOT' } || '/usr/local/decor';
my $DEBUG   = 0;

unshift @INC, $ROOT . '/core/lib';

### PUBLIC ###################################################################

sub de_version
{
  return $VERSION;
}

sub de_root
{
  return $ROOT;
}

sub de_debug_set
{
  my $level  = shift;
  $DEBUG = $level;
  return $DEBUG;
}

sub de_debug_inc
{
  $DEBUG++;
  return $DEBUG;
}

sub de_debug_off
{
  $DEBUG = undef;
  return $DEBUG;
}

sub de_debug
{
  return $DEBUG;
}

### EOF ######################################################################
1;
