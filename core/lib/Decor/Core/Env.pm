##############################################################################
##
##  DECOR application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Env;
use strict;

use Exporter;
BEGIN
{
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_init
                de_init_done

                de_app_name
                de_app_path
                de_bundles
                de_bundles_dirs
                de_app_cfg

                de_version
                de_root
                de_debug
                de_debug_set
                de_debug_inc
                de_debug_off

                );
}

use Data::Lock qw( dlock dunlock );
use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Shared::Utils;
use Decor::Core::Config;
use Decor::Core::Log;

### PRIVATE ##################################################################

my $VERSION = '1.00';
my $ROOT    = $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor';
my $DEBUG   = 0;

unshift @INC, $ROOT . '/core/lib',  $ROOT . '/shared/lib';
my @ORIGINAL_INC = @INC;

my $APP_NAME;

my %APP_CFG;
my %APP_CFG_KEYS = (
                   BUNDLES             => 1,
                   SESSION_EXPIRE_TIME => 1,
                   );

my @BUNDLES;
my @BUNDLES_DIRS;

### PUBLIC ###################################################################

my $_INIT_OK;

sub de_init
{
  my %init  = @_;
  my $app_name = $init{ 'APP_NAME' };
  boom "invalid APP_NAME [$app_name]" unless de_check_name( $app_name );

  if( $_INIT_OK )
    {
    boom "mismatched APP_NAME expected [$APP_NAME] got [$app_name]" unless $APP_NAME eq $app_name;
    return;
    }

  $_INIT_OK = 1;

  dlock $APP_NAME = $app_name;

  boom "invalid ROOT directory [$ROOT] use either [/usr/local/decor] or DECOR_CORE_ROOT env var" unless $ROOT ne '' and -d $ROOT;

  my $app_path = de_app_path();

  boom "cannot find/access application [$APP_NAME] path [$app_path]" unless -d $app_path;
  
  my $log_prefix = $init{ 'LOG_PREFIX' };
  my $log_dir = "$ROOT/var/core/$app_name\_$</log/$log_prefix/";
  dir_path_ensure( $log_dir ) or boom "cannot find/access log dir [$log_dir] for app [$APP_NAME] path [$app_path]";
  de_set_log_dir( $log_dir );

  my $cfg = de_config_load_file( "$app_path/etc/app.conf" );
  if( $cfg )
    {
    %APP_CFG = %{ $cfg = $cfg->{ '@' }{ '@' } };
    }
  else
    {
    %APP_CFG = ();
    }
  @BUNDLES = sort split /[\s\,]+/, $APP_CFG{ 'USE_BUNDLES' };

  unshift @BUNDLES, sort ( read_dir_entries( "$app_path/bundles" ) );

  for my $bundle ( @BUNDLES )
    {
    # FIXME: bad logic, should not complain if no bundles are used at all, report locations and bundle name for other "not-found" errors
    my $found;
    for my $bundle_dir ( ( "$app_path/bundles", "$ROOT/bundles" ) )
      {
      if( -d "$bundle_dir/$bundle" )
        {
        push @BUNDLES_DIRS, "$bundle_dir/$bundle";
        $found = 1;
        last;
        }
      }
    if( ! $found )
      {
      boom( "error: bundle not found [$bundle]" );
      }
    }

  dlock \@BUNDLES;
  dlock \@BUNDLES_DIRS;

  @INC = ( "$app_path/lib", @ORIGINAL_INC );
  #print STDERR Dumper( 'APP_CFG:', \%APP_CFG, 'BUNDLES:', \@BUNDLES, 'BUNDLES DIRS:', \@BUNDLES_DIRS );
}

sub de_init_done
{
  return $APP_NAME ne '';
}

sub de_app_name
{
  boom "call de_init() first to initialize environment!" unless $_INIT_OK;
  return $APP_NAME;
}

sub de_app_path
{
  boom "call de_init() first to initialize environment!" unless $_INIT_OK;
  return "$ROOT/apps/$APP_NAME";
}

sub de_app_cfg
{
  my $key = shift;
  my $def = shift; # default value

  boom "invalid APP_CFG key [$key]" unless exists $APP_CFG_KEYS{ $key };

  my $res = ( exists $APP_CFG{ $key } and $APP_CFG{ $key } ne '' ) ? $APP_CFG{ $key } : $def;

  return $res;
}

sub de_bundles
{
  return \@BUNDLES;
}

sub de_bundles_dirs
{
  return \@BUNDLES_DIRS;
}

sub de_version
{
  return $VERSION;
}

sub de_root
{
  boom "call de_init() first to initialize environment!" unless $_INIT_OK;
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
