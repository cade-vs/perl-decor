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

use parent 'Decor::Core::Base';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

use Decor::Core::Log;
use Decor::Core::Utils;
use Decor::Core::Config;

##############################################################################

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

##############################################################################

sub load
{
  my $self  =    shift;
  my $table = uc shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  $self->{ 'TABLE' } = $table;

  my $stage = $self->get_stage();
  
  my $root         = $stage->get_root_dir();
  my $stage_name   = $stage->get_stage_name();
  my @modules_dirs = $stage->get_modules_dirs();
  
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
  my $des   = $self->{ 'DES'   };
  
  de_check_ref_hash( $des, "empty table description content" );
  boom "unknown field [$field] for table [$table]" unless exists $des->{ $field };

  return $des->{ $field };
}

sub get_des
{
  my $self = shift;
  
  # FIXME: load on create/new and avoid checks here?
  my $des = $self->{ 'DES' };
  boom "empty table description content" unless ref( $des ) eq 'HASH';

  return $des;
}

### EOF ######################################################################
1;
