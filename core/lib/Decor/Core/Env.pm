##############################################################################
##
##  DECOR application machinery core
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  environment settings store, no logic here
##
##  all settings are set once by Decor::Core::Boot via set_env() and then
##  locked by lock_env(), the rest of the code reads them with de_* getters,
##  getters boom on missing settings (i.e. de_boot() was not called)
##
##  @INC is outside decor code space and may be extended at runtime with
##  de_inc_add()
##
##############################################################################
package Decor::Core::Env;
use strict;

use Exporter;
BEGIN
{
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_env
                de_env_exists
                de_init_done

                de_root
                de_app_name
                de_app_dir
                de_app_cfg
                de_log_dir
                de_bundles
                de_bundles_dirs

                de_version

                de_inc_add
                de_inc_list

                );
}

use Exception::Sink;

##############################################################################

my $VERSION = '1.01';

my %ENV_SETTINGS;
my $ENV_LOCKED;

### SETTINGS, NOT EXPORTED, ONLY FOR Decor::Core::Boot #######################

sub __check_boot_caller
{
  my $caller = ( caller( 1 ) )[ 0 ];
  my $func   = ( caller( 1 ) )[ 3 ];
  boom "$func is reserved for Decor::Core::Boot, called from [$caller]" unless $caller eq 'Decor::Core::Boot';
}

# set_env( 'NAME', $value ) sets value once, refuses existing names and any
# setting after lock_env(); references should be locked by the caller
sub set_env
{
  __check_boot_caller();

  my $name  = uc shift;
  my $value = shift;

  boom "invalid environment setting name [$name]" unless $name =~ /^[A-Z_0-9]+$/;
  boom "environment is locked, cannot set [$name]" if $ENV_LOCKED;
  boom "environment setting [$name] is already set" if exists $ENV_SETTINGS{ $name };

  $ENV_SETTINGS{ $name } = $value;
  return 1;
}

# lock_env() finishes the setup, no more set_env() after that
sub lock_env
{
  __check_boot_caller();

  $ENV_LOCKED = 1;
  return 1;
}

# reset_env() clears all settings and the lock (for re-boot, i.e. tests)
sub reset_env
{
  __check_boot_caller();

  %ENV_SETTINGS = ();
  $ENV_LOCKED   = undef;
  return 1;
}

### GETTERS ##################################################################

# de_env( 'NAME' ) returns setting value, booms if it is not set
sub de_env
{
  my $name = uc shift;

  boom "environment setting [$name] is not set, call de_boot() first" unless exists $ENV_SETTINGS{ $name };
  return $ENV_SETTINGS{ $name };
}

sub de_env_exists
{
  return exists $ENV_SETTINGS{ uc shift } ? 1 : 0;
}

# true when the environment is fully set up and locked by de_boot()
sub de_init_done
{
  return $ENV_LOCKED ? 1 : 0;
}

sub de_root
{
  return de_env( 'ROOT' );
}

sub de_app_name
{
  return de_env( 'APP_NAME' );
}

sub de_app_dir
{
  return de_env( 'APP_DIR' );
}

sub de_log_dir
{
  return de_env( 'LOG_DIR' );
}

sub de_bundles
{
  return de_env( 'BUNDLES' );
}

sub de_bundles_dirs
{
  return de_env( 'BUNDLES_DIRS' );
}

# de_app_cfg( 'KEY', $default ) value from app.conf, default if missing or empty
sub de_app_cfg
{
  my $key = uc shift;
  my $def = shift; # default value

  my $cfg = de_env( 'APP_CFG' );

  return ( exists $cfg->{ $key } and $cfg->{ $key } ne '' ) ? $cfg->{ $key } : $def;
}

sub de_version
{
  return $VERSION;
}

### @INC #####################################################################

# de_inc_add( @dirs ) prepends dirs to @INC (in given order), skips existing
sub de_inc_add
{
  my %have = map { $_ => 1 } grep { ! ref } @INC;
  unshift @INC, grep { ! $have{ $_ }++ } @_;
  return scalar @INC;
}

sub de_inc_list
{
  return [ @INC ];
}

### EOF ######################################################################
1;
