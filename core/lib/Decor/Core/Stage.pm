##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Stage;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Log;
use Decor::Core::Config;
use Decor::Core::Table::Description;

my %DE_STAGE_VALIDATE = (
                      ROOT => '-d',
                      );

my %DE_STAGE_DEFAULTS = (
                      ROOT => '',
                      );

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my $stage_name = shift;
  boom "invalid STAGE_NAME stagelication name [$stage_name]" unless de_check_name( $stage_name );
  
  my $self = {
             STAGE_NAME => $stage_name,
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
  
  my $stage_name = $self->{ 'STAGE_NAME' };
  my $stage_path = "$root/apps/$stage_name";

  boom "cannot find/access stage path [$stage_path]" unless -d $stage_path;

  my $cfg = de_config_load_file( "$stage_path/etc/stage.cfg" );

  my @modules = sort split /[\s\,]+/, $cfg->{ '@' }{ 'MODULES' };
  
  unshift @modules, sort ( read_dir_entries( "$stage_path/modules" ) );
  
  my @modules_dirs;
  for my $module ( @modules )
    {
    my $found;
    for my $mod_dir ( ( "$stage_path/modules", "$root/modules" ) )
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

sub get_stage_name
{
  my $self  = shift;

  return $self->{ 'STAGE_NAME' };
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

  my $cache = $self->__get_cache_storage( 'TABLE_DES' );
  if( exists $cache->{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: table description cache hit for [$table]" );
    return $cache->{ $table };
    }

  my $des = Decor::Core::Table::Description->new( STAGE => $self );
  $des->load( $table );
  $cache->{ $table } = $des;
  
  return $des;
}

### INTERNALS ################################################################

sub __get_cache_storage
{
  my $self = shift;
  my $key  = shift;
  
  $self->{ 'CACHE_STORAGE' }{ $key } ||= {};
  return $self->{ 'CACHE_STORAGE' }{ $key };
}

### EOF ######################################################################
1;
