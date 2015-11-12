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
use Data::Tools;

use Decor::Core::Log;
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
  my $self  =    shift;
  my $table = uc shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  $self->{ 'TABLE' } = $table;

  if( exists $self->{ 'CACHE' }{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    de_log( "status: table description cache hit for [$table]" );
    my $des = $self->{ 'DES' } = $self->{ 'CACHE' }{ $table };
    return $des;
    }

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
    

    }

  print STDERR "TABLE DES POST PROCESSSED [$table]:" . Dumper( $des );

  hash_lock_recursive( $des );
  $self->{ 'DES' } = $self->{ 'CACHE' }{ $table } = $des;
  
  return 1;
}

sub fields
{
  my $self  =    shift;
  
  my $des = $self->{ 'DES' };
  boom "empty table description content" unless ref( $des ) eq 'HASH';
  
  return grep { $_ ne '@' } keys %$des;
}

sub get_table_des
{
  my $self  =    shift;
  
  # FIXME: load on create/new and avoid checks here?
  my $des = $self->{ 'DES' };
  boom "empty table description content" unless ref( $des ) eq 'HASH';

  return $des->{ '@' };
}

sub get_field_des
{
  my $self  =    shift;
  my $field = uc shift;
  
  # FIXME: load on create/new and avoid checks here?
  my $table = $self->{ 'TABLE' };
  my $des   = $self->{ 'DES' };
  boom "empty table description content" unless ref( $des ) eq 'HASH';
  boom "unknown field [$field] for table [$table]" unless exists $des->{ $field };

  return $des->{ $field };
}

sub get_des
{
  my $self  =    shift;
  
  # FIXME: load on create/new and avoid checks here?
  my $des = $self->{ 'DES' };
  boom "empty table description content" unless ref( $des ) eq 'HASH';

  return $des;
}



### EOF ######################################################################
1;
