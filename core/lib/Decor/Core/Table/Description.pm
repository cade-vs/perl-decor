##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Description;
use strict;

use Data::Dumper;
use Exception::Sink;

use Decor::Core::Utils;
use Decor::Core::Config;

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my %args = @_;
  
  my $app = $args{ 'APP' };
  boom "invalid APP ref [$app]" unless ref( $app ) eq 'Decor::Core::Application';

  my $cache = $app->__get_cache_storage( 'TABLE_DESCRIPTIONS' );
  
  my $self = {
             APP   => $app,
             CACHE => $cache,
             };
  bless $self, $class;
  
  de_obj_add_debug_info( $self );   # FIXME: usually called from factory?
  return $self;
}

sub load
{
  my $self  = shift;
  my $table = shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  $self->{ 'TABLE' } = $table;

  my $app = $self->{ 'APP' };
  
  my $root         = $app->get_root_dir();
  my $app_name     = $app->get_app_name();
  my @modules_dirs = $app->get_modules_dirs();
  
  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @modules_dirs;
  push @dirs, "$root/apps/$app_name/tables";

  print STDERR 'TABLE DES DIRS:' . Dumper( \@dirs );

  my $des = de_config_load( "$table", \@dirs );

  print STDERR "TABLE DES [$table]:" . Dumper( $des );

}


### EOF ######################################################################
1;
