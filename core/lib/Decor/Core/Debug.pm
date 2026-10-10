##############################################################################
##
##  Decor application machinery core
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  debug level state, independent from the rest of the code
##
##############################################################################
package Decor::Core::Debug;
use strict;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_debug
                de_debug_set
                de_debug_inc
                de_debug_dec
                de_debug_off
                de_debug_from_env

                );

my $DEBUG = 0;

sub de_debug
{
  return $DEBUG;
}

sub de_debug_set
{
  $DEBUG = shift;
  return $DEBUG;
}

sub de_debug_inc
{
  $DEBUG++;
  return $DEBUG;
}

sub de_debug_dec
{
  $DEBUG-- if $DEBUG > 0;
  return $DEBUG;
}

sub de_debug_off
{
  $DEBUG = undef;
  return $DEBUG;
}

# sets debug level from program environment variable, DECOR_DEBUG by default,
# only if the variable is set to a number, returns current debug level
sub de_debug_from_env
{
  my $name = shift || 'DECOR_DEBUG';

  $DEBUG = $ENV{ $name } if defined $ENV{ $name } and $ENV{ $name } =~ /^\d+$/;
  return $DEBUG;
}

### EOF ######################################################################
1;
