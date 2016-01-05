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


### TABLE DESCRIPTIONS #######################################################

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
    
  # more postprocessing work
  $des->{ '@' }{ '_TABLE_NAME'  } = $table;
  $des->{ '@' }{ '_FIELDS_LIST' } = [ grep /[^:@]/, keys %$des ];

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

### EOF ######################################################################
1;
