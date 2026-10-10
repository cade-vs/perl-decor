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
##  core boot: sets up the environment and links all core parts together
##
##  used only by the outside world (scripts, servers, tests), no Decor::Core
##  module may use Boot, Boot may use any of them
##
##  de_boot() resolves root, app dir, log dir, app config, bundles, @INC,
##  stores results in Decor::Core::Env (set once, then locked) and links
##  description source for Decor::Shared::Describe
##
##############################################################################
package Decor::Core::Boot;
use strict;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_boot

                );

use Data::Lock qw( dlock );
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Shared::Utils;
use Decor::Shared::Config;
use Decor::Shared::Types;
use Decor::Shared::Describe;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Loader;
use Decor::Core::Loader::Table;
use Decor::Core::Loader::Menu;

##############################################################################

# de_boot( APP_NAME => 'app', LOG_PREFIX => 'prefix', ROOT => '/path', PRELOAD => 1 )
#
#   APP_NAME    required, application name
#   LOG_PREFIX  optional, log dir sub-directory
#   ROOT        optional, decor root dir, default DECOR_CORE_ROOT program
#               environment variable or /usr/local/decor
#   PRELOAD     optional, preload all tables descriptions and menus
#
# calling de_boot() again for the same application does nothing,
# different application name booms
#
sub de_boot
{
  my %init = @_;

  my $app_name = $init{ 'APP_NAME' };
  boom "invalid APP_NAME [$app_name]" unless de_check_name( $app_name );

  if( de_init_done() )
    {
    my $booted_app_name = de_app_name();
    boom "mismatched APP_NAME expected [$booted_app_name] got [$app_name]" unless $booted_app_name eq $app_name;
    return 1;
    }

  data_tools_set_text_io_utf8();

  # --- root ------------------------------------------------------------------

  my $root = $init{ 'ROOT' } || $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor';
  boom "invalid ROOT directory [$root] use either [/usr/local/decor] or DECOR_CORE_ROOT env var" unless $root ne '' and -d $root;

  Decor::Core::Env::set_env( 'ROOT', $root );
  de_inc_add( "$root/core/lib", "$root/shared/lib" );

  # --- application -----------------------------------------------------------

  Decor::Core::Env::set_env( 'APP_NAME', $app_name );

  # TODO: move app dir entirely out of decor dir structure
  my ( $app_dir ) = grep { -d } ( "$root/apps/$app_name", "$root/apps/$app_name-app-decor", "$root/apps/decor-app-$app_name" );
  boom "cannot find/access application [$app_name] app dir in root [$root]" unless $app_dir;

  Decor::Core::Env::set_env( 'APP_DIR', $app_dir );

  # --- log dir ---------------------------------------------------------------

  my $log_prefix = $init{ 'LOG_PREFIX' };
  my $log_dir = "$root/var/core/$app_name\_$</log/$log_prefix/";
  dir_path_ensure( $log_dir ) or boom "cannot find/access log dir [$log_dir] for app [$app_name] path [$app_dir]";

  Decor::Core::Env::set_env( 'LOG_DIR', $log_dir );

  # --- application config ----------------------------------------------------

  # FIXME: common simple config load for arbitrary config files
  my $cfg = de_config_load_file( "$app_dir/etc/app.conf" );
  my %app_cfg = $cfg ? %{ $cfg->{ '@' }{ '@' } } : ();
  dlock \%app_cfg;

  Decor::Core::Env::set_env( 'APP_CFG', \%app_cfg );

  # --- bundles ---------------------------------------------------------------

  my @bundles = sort split /[\s\,]+/, exists $app_cfg{ 'USE' } ? $app_cfg{ 'USE' } : ''; # app cfg is locked, missing keys must not be accessed
  # FIXME: should allow excluding bundles for temporary or debug with "-bundle" f.e.

  # FIXME: should be used explicitly with use bundles?
  # unshift @bundles, sort ( read_dir_entries( "$app_dir/bundles" ) );

  my @bundles_dirs;
  my @inc;
  my @etc;

  for my $bundle ( @bundles )
    {
    boom "error: invalid bundle name [$bundle]! check USE in app.conf" unless de_check_name_ext( $bundle );
    # FIXME: bad logic, should not complain if no bundles are used at all,
    # report locations and bundle name for other "not-found" errors
    my $found;
    for my $bundle_dir ( ( "$app_dir/bundles", "$root/bundles" ) )
      {
      if( -d "$bundle_dir/$bundle" )
        {
        my $bd = "$bundle_dir/$bundle";
        push @bundles_dirs, $bd;
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

  my @etc_dirs = ( @etc, "$root/core/lib" );

  dlock \@bundles;
  dlock \@bundles_dirs;
  dlock \@inc;
  dlock \@etc_dirs;

  Decor::Core::Env::set_env( 'BUNDLES',      \@bundles      );
  Decor::Core::Env::set_env( 'BUNDLES_DIRS', \@bundles_dirs );
  Decor::Core::Env::set_env( 'LIB_DIRS',     \@inc          );
  Decor::Core::Env::set_env( 'ETC_DIRS',     \@etc_dirs     );

  de_inc_add( @inc );

  # --- shared setup ----------------------------------------------------------

  type_set_format( { NAME => 'UTIME' }, 'YMD24' );

  # --- links -----------------------------------------------------------------

  loader_reset();
  des_set_source( \&load_table );

  # --- done ------------------------------------------------------------------

  Decor::Core::Env::lock_env();

  if( $init{ 'PRELOAD' } )
    {
    load_tables_preload();
    load_menus_preload();
    }

  return 1;
}

# de_boot_reset() clears environment and loaders state (for re-boot, i.e. tests)
sub de_boot_reset
{
  Decor::Core::Env::reset_env();
  loader_reset();
  load_tables_reset();
  load_menus_reset();
  return 1;
}

### EOF ######################################################################
1;
