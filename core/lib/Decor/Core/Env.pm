##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
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
                de_app_name
                de_app_path
                de_modules
                de_modules_dirs
                
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

### PRIVATE ##################################################################

my $VERSION = '1.00';
my $ROOT    = $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor';
my $DEBUG   = 0;

unshift @INC, $ROOT . '/core/lib',  $ROOT . '/shared/lib';

my $APP_NAME;
my @MODULES;
my @MODULES_DIRS;

### PUBLIC ###################################################################


my $_INIT_OK;

sub de_init
{
  my %init  = @_;
  $_INIT_OK = 1;
  
  dlock $APP_NAME = $init{ 'APP_NAME' };
  boom "invalid APP_NAME [$APP_NAME]" unless de_check_name( $APP_NAME );

  boom "invalid ROOT directory [$ROOT] use either [/usr/local/decor] or DECOR_ROOT env var" unless $ROOT ne '' and -d $ROOT;

  my $app_path = de_app_path();

  boom "cannot find/access application [$APP_NAME] path [$app_path]" unless -d $app_path;

  my $cfg = de_config_load_file( "$app_path/etc/app.cfg" );
  $cfg = $cfg->{ '@' }{ '@' } if $cfg;

  @MODULES = sort split /[\s\,]+/, $cfg->{ 'MODULES' };
  
  unshift @MODULES, sort ( read_dir_entries( "$app_path/modules" ) );
  
  for my $module ( @MODULES )
    {
    my $found;
    for my $mod_dir ( ( "$app_path/modules", "$ROOT/modules" ) )
      {
      if( -d "$mod_dir/$module" )
        {
        push @MODULES_DIRS, "$mod_dir/$module";
        $found = 1;
        last;
        }
      }
    if( ! $found )  
      {
      boom( "error: module not found [$module]" );
      }
    }

  dlock \@MODULES;
  dlock \@MODULES_DIRS;
  
  print STDERR 'CONFIG:' . Dumper( $cfg, \@MODULES, \@MODULES_DIRS );
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

sub de_modules
{
  return \@MODULES;
}

sub de_modules_dirs
{
  return \@MODULES_DIRS;
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
