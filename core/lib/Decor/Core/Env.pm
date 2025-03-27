##############################################################################
##
##  DECOR application machinery core
##  2014-2023 (c) Vladi Belperchinov-Shabanski "Cade"
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
                de_app_dir
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

use Decor::Shared::Types;
use Decor::Shared::Utils;
use Decor::Shared::Config;
use Decor::Core::Log;

$Data::Dumper::Sortkeys = 1;

### PRIVATE ##################################################################

my $VERSION = '1.01';
my $ROOT    = $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor';
my $DEBUG   = 0;

unshift @INC, $ROOT . '/core/lib',  $ROOT . '/shared/lib';
my @ORIGINAL_INC = @INC;

my $APP_NAME;

my %APP_CFG;
my %APP_CFG_KEYS = (
                   USE                      => 1, # bundles
                   SESSION_ANON_EXPIRE_TIME => 1,
                   SESSION_USER_EXPIRE_TIME => 1,
                   );

my @BUNDLES;
my @BUNDLES_DIRS;
my @ETC_DIRS;

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
  
  data_tools_set_text_io_utf8();

  dlock $APP_NAME = $app_name;

  boom "invalid ROOT directory [$ROOT] use either [/usr/local/decor] or DECOR_CORE_ROOT env var" unless $ROOT ne '' and -d $ROOT;

  my $app_dir = de_app_dir();

  boom "cannot find/access application [$APP_NAME] path [$app_dir]" unless -d $app_dir;
  
  my $log_prefix = $init{ 'LOG_PREFIX' };
  my $log_dir = "$ROOT/var/core/$app_name\_$</log/$log_prefix/";
  dir_path_ensure( $log_dir ) or boom "cannot find/access log dir [$log_dir] for app [$APP_NAME] path [$app_dir]";
  de_set_log_dir( $log_dir );

  my $cfg = de_config_load_file( "$app_dir/etc/app.conf" );
  if( $cfg )
    {
    %APP_CFG = %{ $cfg = $cfg->{ '@' }{ '@' } };
    }
  else
    {
    %APP_CFG = ();
    }

  @BUNDLES = sort split /[\s\,]+/, de_app_cfg( 'USE' );
  # FIXME: should allow excluding bundles for temporary or debug with "-bundle" f.e.

  # FIXME: should be used explicitly with use bundles?
  # unshift @BUNDLES, sort ( read_dir_entries( "$app_dir/bundles" ) );

  my @inc;
  my @etc;

  for my $bundle ( @BUNDLES )
    {
    boom "error: invalid bundle name [$bundle]! check USE_BUNDLES in app.conf" unless de_check_name_ext( $bundle );
    # FIXME: bad logic, should not complain if no bundles are used at all, 
    # report locations and bundle name for other "not-found" errors
    my $found;
    for my $bundle_dir ( ( "$app_dir/bundles", "$ROOT/bundles" ) )
      {
      if( -d "$bundle_dir/$bundle" )
        {
        my $bd = "$bundle_dir/$bundle";
        push @BUNDLES_DIRS, $bd;
        push @inc, "$bd/lib";
        push @etc, "$bd/etc";
        $found = 1;
        last;
        }
      }
    if( ! $found )
      {
      boom( "error: bundle not found [$bundle]" );
      }
    }

  push @inc, "$app_dir/lib";
  push @etc, "$app_dir/etc";

  @ETC_DIRS = ( @etc, $ROOT . '/core/lib' );

  dlock \@BUNDLES;
  dlock \@BUNDLES_DIRS;
  dlock \@ETC_DIRS;

  type_set_format({NAME => 'UTIME'},'YMD24');
  
  @INC = ( @inc, @ORIGINAL_INC );
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

sub de_app_dir
{
  boom "call de_init() first to initialize environment!" unless $_INIT_OK;
  # TODO: move app dir entirely out of decor dir structure
  for( "$ROOT/apps/$APP_NAME", "$ROOT/apps/$APP_NAME-app-decor", "$ROOT/apps/decor-app-$APP_NAME" )
    {
    return $_ if -d;
    }
  boom "app dir root cannot be found for [$ROOT] app name [$APP_NAME]!" unless $_INIT_OK;
}

sub de_app_cfg
{
  my $key = uc shift;
  my $def = shift; # default value

  # FIXME: URGENT! more flexible approach...
  #boom "invalid APP_CFG key [$key]" unless exists $APP_CFG_KEYS{ $key };

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
