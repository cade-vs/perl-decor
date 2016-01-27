##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
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

my %DES_KEY_TYPES = (
                      'ALLOW' => '@',
                      'DENY'  => '@',
                    );

my @TABLE_ATTRS = qw(
                      LABEL
                      ALLOW
                      DENY
                    );
                    
my @FIELD_ATTRS = qw(
                      LABEL
                      TYPE
                      TYPE_LEN
                      TYPE_DOT
                      ALLOW
                      DENY
                    );

my %TABLE_ATTRS = map { $_ => 1 } @TABLE_ATTRS;
hash_lock_recursive( \%TABLE_ATTRS );
my %FIELD_ATTRS = map { $_ => 1 } @FIELD_ATTRS;
hash_lock_recursive( \%FIELD_ATTRS );

sub __get_tables_dirs
{
  my $self  =    shift;
  
  return $self->{ 'CACHE' }{ 'TABLES_DIRS_AR' } if exists $self->{ 'CACHE' }{ 'TABLES_DIRS_AR' };
  
  my $root         = $self->get_root_dir();
  my $stage_name   = $self->get_stage_name();
  my @modules_dirs = $self->get_modules_dirs();
  
  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @modules_dirs;
  push @dirs, "$root/apps/$stage_name/tables";

  $self->{ 'CACHE' }{ 'TABLES_DIRS_HR' } = \@dirs;

  return \@dirs;
}

sub get_tables_list
{
  my $self  =    shift;

  return $self->{ 'CACHE' }{ 'TABLES_LIST_AR' } if exists $self->{ 'CACHE' }{ 'TABLES_LIST_AR' };

  my $tables_dirs = $self->__get_tables_dirs();

  print STDERR 'TABLE DES DIRS:' . Dumper( $tables_dirs );
  
  my @tables;
  
  for my $dir ( @$tables_dirs )
    {
    print STDERR "$dir/*.def\n";
    push @tables, ( sort( glob_tree( "$dir/*.def" ) ) );
    }

  s/^.*?\/([^\/]+)\.def$/uc($1)/ie for @tables;
  @tables = keys %{ { map { $_ => 1 } @tables } };

  $self->{ 'CACHE' }{ 'TABLES_LIST_AR' } = \@tables;

  return \@tables;
}

sub __load_table_des_hash
{
  my $self  =    shift;
  my $table = uc shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  $self->{ 'TABLE' } = $table;

  my $tables_dirs = $self->__get_tables_dirs();

  print STDERR 'TABLE DES DIRS:' . Dumper( $tables_dirs );

  my $des = de_config_load( "$table", $tables_dirs, { KEY_TYPES => \%DES_KEY_TYPES } );

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

    # convert allow/deny list to access tree
    __preprocess_allow_deny( $des->{ $field } );

    # add empty keys to fields description before locking
    for my $attr ( @FIELD_ATTRS )
      {
      next if exists $des->{ $field }{ $attr };
      $des->{ $field }{ $attr } = undef;
      }
    }

  # convert allow/deny list to access tree
  __preprocess_allow_deny( $des->{ '@' } );

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
  my $table = uc shift;

  my $cache = $self->__get_cache_storage( 'TABLE_DES' );
  #my $cache = $self->{ 'TABLE_DES_CACHE' };
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

sub __preprocess_allow_deny
{
  my $hr = shift;

  for my $allow_deny ( qw( ALLOW DENY ) )
    {
    $hr->{ $allow_deny } ||= [];
    my %access;
    for my $line ( @{ $hr->{ $allow_deny } } )
      {
      my %a = __describe_parse_access_line( $line );
      %access = ( %access, %a );
      }
    $hr->{ $allow_deny } = \%access;
    }
}

sub __describe_parse_access_line
{
  my $line = lc shift;
  
  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

#print "ACCESS DEBUG LINE [$line]\n";
  boom "invalid access line, keywords must not be separated by whitespace [$line]" if $line =~ /[a-z_0-9]\s+[a-z_0-9]/i;

  $line =~ s/\s*//g;
#print "ACCESS DEBUG LINE [$line]\n";

  my @line = split /;/, $line;

  my $ops = shift @line;
  my @ops = split /[,]+/, $ops;

  my %access;
  
  for my $op ( @ops )
    {
    $access{ uc $op } = [ map { [ split /[\s\+]+/ ] } @line ];
    }
  
  return %access;
}

### EOF ######################################################################
1;
