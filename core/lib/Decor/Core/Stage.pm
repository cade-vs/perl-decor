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
             STAGE_NAME      => $stage_name,
             TABLE_DES_CACHE => {},
             };
  bless $self, $class;

  $self->{ 'CACHE_STORAGE' }{ 'TABLE_DES' } = {};  

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

my @TABLE_ATTRS = qw(
                      LABEL
                    );
                    
my @FIELD_ATTRS = qw(
                      LABEL
                      TYPE
                      TYPE_LEN
                      TYPE_DOT
                    );

my %TABLE_ATTRS = map { $_ => 1 } @TABLE_ATTRS;
hash_lock_recursive( \%TABLE_ATTRS );
my %FIELD_ATTRS = map { $_ => 1 } @FIELD_ATTRS;
hash_lock_recursive( \%FIELD_ATTRS );

sub __load_table_des_hash
{
  my $self  =    shift;
  my $table = uc shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  $self->{ 'TABLE' } = $table;

  my $root         = $self->get_root_dir();
  my $stage_name   = $self->get_stage_name();
  my @modules_dirs = $self->get_modules_dirs();
  
  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @modules_dirs;
  push @dirs, "$root/apps/$stage_name/tables";

  print STDERR 'TABLE DES DIRS:' . Dumper( \@dirs );

  my $des = de_config_load( "$table", \@dirs );

  print STDERR "TABLE DES RAW [$table]:" . Dumper( $des );
  
  # postprocessing
  for my $field ( keys %$des )
    {
    next if $field eq '@'; # self

    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $des->{ $field }{ 'TYPE' };
    my $type = shift @type;
    $des->{ $field }{ 'TYPE' } = $type;
    if( $type eq 'CHAR' )
      {
      my $len = shift( @type ) || 256;
      $des->{ $field }{ 'TYPE_LEN' } = $len;
      }
    elsif( $type eq 'INT' )  
      {
      my $len = shift( @type );
      $des->{ $field }{ 'TYPE_LEN' } = $len if $len > 0;
      }
    elsif( $type eq 'REAL' )  
      {
      my $spec = shift( @type );
      if( $spec =~ /^(\d*)(\.(\d*))?/ )
        {
        my $len = $1;
        my $dot = $3;
        $des->{ $field }{ 'TYPE_LEN' } = $len if $len > 0;
        $des->{ $field }{ 'TYPE_DOT' } = $dot if $dot ne '';
        }
      }

    # --- allow ---------------------------------------------
    

    # add empty keys to fields description before locking
    for my $attr ( @FIELD_ATTRS )
      {
      next if exists $des->{ $field }{ $attr };
      $des->{ $field }{ $attr } = undef;
      }
    }


  # add empty keys to table description before locking
  for my $attr ( @TABLE_ATTRS )
    {
    next if exists $des->{ '@' }{ $attr };
    $des->{ '@' }{ $attr } = undef;
    }

  print STDERR "TABLE DES POST PROCESSSED [$table]:" . Dumper( $des );

  bless $des, 'Decor::Core::Table::Description';
  hash_lock_recursive( $des );
  
  return $des;
}


sub describe_table
{
  my $self  = shift;
  my $table = shift;

  #my $cache = $self->__get_cache_storage( 'TABLE_DES' );
  my $cache = $self->{ 'TABLE_DES_CACHE' };
  if( exists $cache->{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: table description cache hit for [$table]" );
    return $cache->{ $table };
    }

  my $des = $self->__load_table_des_hash( $table );

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
