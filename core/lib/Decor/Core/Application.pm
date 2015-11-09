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

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Log;
use Decor::Core::Config;
use Decor::Core::Table::Description;

my %DE_APP_VALIDATE = (
                      ROOT => '-d',
                      );

my %DE_APP_DEFAULTS = (
                      ROOT => '',
                      );

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my $app_name = shift;
  boom "invalid APP_NAME application name [$app_name]" unless de_check_name( $app_name );
  
  my $self = {
             APP_NAME => $app_name,
             };
  bless $self, $class;
  
  de_obj_add_debug_info( $self );  
  return $self;
}

sub init
{
  my $self = shift;
  my $root = shift;
  boom "invalid ROOT directory [$root]" unless $root ne '' and -d $root;

  $self->{ 'ROOT' } = $root;
  
  my $app_name = $self->{ 'APP_NAME' };
  
  my $cfg = de_config_load_file( "$root/apps/$app_name/etc/app.cfg" );

  my @modules = sort split /[\s\,]+/, $cfg->{ '@' }{ 'MODULES' };
  
  unshift @modules, sort ( read_dir_entries( "$root/apps/$app_name/modules" ) );
  
  my @modules_dirs;
  for my $module ( @modules )
    {
    my $found;
    for my $mod_dir ( ( "$root/apps/$app_name/modules", "$root/modules" ) )
      {
      if( -d "$mod_dir/$module" )
        {
        push @modules_dirs, "$mod_dir/$module";
        $found = 1;
        last;
        }
      }
    if( ! $found )  
      {
      boom( "error: module not found [$module]" );
      }
    }

  $self->{ 'MODULES'      } = \@modules;
  $self->{ 'MODULES_DIRS' } = \@modules_dirs;
  
  print STDERR 'CONFIG:' . Dumper( $cfg, \@modules, \@modules_dirs );

}

### ##########################################################################

sub get_root_dir
{
  my $self  = shift;

  return $self->{ 'ROOT' };
}

sub get_app_name
{
  my $self  = shift;

  return $self->{ 'APP_NAME' };
}

sub get_modules
{
  my $self  = shift;

  return @{ $self->{ 'MODULES'      } };
}

sub get_modules_dirs
{
  my $self  = shift;

  return @{ $self->{ 'MODULES_DIRS' } };
}

### ##########################################################################

sub describe_table
{
  my $self  = shift;
  my $table = shift;

  my $des = Decor::Core::Table::Description->new( APP => $self );
  $des->load( $table );
  
  return $des;
}

### INTERNALS ################################################################

sub __get_cache_storage
{
  my $self = shift;
  my $key  = shift;
  
  $self->{ 'CACHE_STORAGE' }{ $key } ||= [];
  return $self->{ 'CACHE_STORAGE' }{ $key };
}

### EOF ######################################################################
1;
