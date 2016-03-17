##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Describe;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Log;
use Decor::Core::Config;
use Decor::Core::Table::Description;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                des_reset
                
                des_get_tables_list
                describe_table 
                
                );

### TABLE DESCRIPTIONS #######################################################

my %TYPE_ATTRS = (
                      'NAME' => undef,
                      'LEN'  => undef,
                      'DOT'  => undef,
                 );

my %DES_KEY_TYPES = (
                      'ALLOW' => '@',
                      'DENY'  => '@',
                    );

my @TABLE_ATTRS = qw(
                      SCHEMA
                      LABEL
                      ALLOW
                      DENY
                    );
                    
# FIXME: more categories INDEX: ACTION: etc.
my %DES_ATTRS = (
                  '@' => {
                           SCHEMA => 1,
                           LABEL  => 1,
                           ALLOW  => 1,
                           DENY   => 1,
                         },
                  'FIELD' => {
                           TYPE   => 1,
                           LABEL  => 1,
                           ALLOW  => 1,
                           DENY   => 1,
                         },
                );

my %DES_LINK_ATTRS = (
                  'FIELD' => {
                           ALLOW  => 1,
                           DENY   => 1,
                         },
                );
               
#my %TABLE_ATTRS = map { $_ => 1 } @TABLE_ATTRS;
#hash_lock_recursive( \%TABLE_ATTRS );
#my %FIELD_ATTRS = map { $_ => 1 } @FIELD_ATTRS;
#hash_lock_recursive( \%FIELD_ATTRS );

#-----------------------------------------------------------------------------

my %DES_CACHE;

sub des_reset
{
  %DES_CACHE = ();
  
  return 1;
}

#-----------------------------------------------------------------------------

sub __get_tables_dirs
{
  return $DES_CACHE{ 'TABLES_DIRS_AR' } if exists $DES_CACHE{ 'TABLES_DIRS_AR' };
  
  my $root         = de_root();
  my $app_path     = de_app_path();
  my $modules_dirs = de_modules_dirs();
  
  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @$modules_dirs;
  push @dirs, "$app_path/tables";

  $DES_CACHE{ 'TABLES_DIRS_AR' } = \@dirs;

  return \@dirs;
}

#-----------------------------------------------------------------------------

sub des_get_tables_list
{
  return $DES_CACHE{ 'TABLES_LIST_AR' } if exists $DES_CACHE{ 'TABLES_LIST_AR' };

  my $tables_dirs = __get_tables_dirs();

  #print STDERR 'TABLE DES DIRS:' . Dumper( $tables_dirs );
  
  my @tables;
  
  for my $dir ( @$tables_dirs )
    {
    print STDERR "$dir/*.def\n";
    push @tables, ( sort( glob_tree( "$dir/*.def" ) ) );
    }

  s/^.*?\/([^\/]+)\.def$/uc($1)/ie for @tables;
  @tables = keys %{ { map { $_ => 1 } @tables } };

  $DES_CACHE{ 'TABLES_LIST_AR' } = \@tables;

  return \@tables;
}

#-----------------------------------------------------------------------------

sub __load_table_des_hash
{
  my $table = uc shift;

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  my $tables_dirs = __get_tables_dirs();

  #print STDERR 'TABLE DES DIRS:' . Dumper( $tables_dirs );

  my $des = de_config_load( $table, 
                            $tables_dirs, 
                            { 
                              KEY_TYPES        => \%DES_KEY_TYPES, 
                              DEFAULT_CATEGORY => 'FIELD',
                              CATEGORIES       => { '@' => 1, 'FIELD' => 1, 'INDEX' => 1 },
                            } 
                          );

###  print STDERR "TABLE DES RAW [$table]:" . Dumper( $des );
  
  boom "unknown table [$table]" unless $des;
  
  # postprocessing TABLE (self) ---------------------------------------------
  my @fields = keys %{ $des->{ 'FIELD' } };

  # move table config in more comfortable location
  $des->{ '@' } = $des->{ '@' }{ '@' };

  # convert allow/deny list to access tree
  __preprocess_allow_deny( $des->{ '@' } );

  # add empty keys to table description before locking
  for my $attr ( keys %{ $DES_ATTRS{ '@' } } )
    {
    next if exists $des->{ '@' }{ $attr };
    $des->{ '@' }{ $attr } = undef;
    }
    
  # more postprocessing work
  $des->{ '@' }{ '_TABLE_NAME'  } = $table;
  $des->{ '@' }{ '_FIELDS_LIST' } = \@fields;
  $des->{ '@' }{ 'DSN'          } = uc( $des->{ '@' }{ 'DSN' } ) || 'MAIN';

###  print STDERR "TABLE DES AFTER SELF PP [$table]:" . Dumper( $des );
  # postprocessing FIELDs ---------------------------------------------------
  
  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    my $type_des = { %TYPE_ATTRS };
    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $fld_des->{ 'TYPE' };
    my $type = shift @type;
    
    # FIXME: check if type is allowed!
    $type_des->{ 'NAME' } = $type;
    if( $type eq 'CHAR' )
      {
      my $len = shift( @type );
      $len = 256 if $len eq '';
      $type_des->{ 'LEN' } = $len;
      }
    elsif( $type eq 'INT' )  
      {
      my $len = shift( @type );
      $type_des->{ 'LEN' } = $len if $len > 0;
      }
    elsif( $type eq 'REAL' )  
      {
      my $spec = shift( @type );
      if( $spec =~ /^(\d*)(\.(\d*))?/ )
        {
        my $len = $1;
        my $dot = $3;
        $type_des->{ 'LEN' } = $len if $len > 0;
        $type_des->{ 'DOT' } = $dot if $dot ne '';
        }
      }
    $fld_des->{ 'TYPE' } = $type_des;
    
    # convert allow/deny list to access tree
    __preprocess_allow_deny( $des->{ 'FIELD' }{ $field } );

    # FIXME: more categories INDEX: ACTION: etc.
    # inherit empty keys
    for my $attr ( keys %{ $DES_LINK_ATTRS{ 'FIELD' } } )
      {
      next if exists $des->{ 'FIELD' }{ $field }{ $attr };
      # link missing attributes to self
      $des->{ 'FIELD' }{ $field }{ $attr } = $des->{ '@' }{ $attr };
      }
    # add empty keys to fields description before locking
    for my $attr ( keys %{ $DES_ATTRS{ 'FIELD' } } )
      {
      next if exists $des->{ 'FIELD' }{ $field }{ $attr };
      $des->{ 'FIELD' }{ $field }{ $attr } = undef;
      }
    }

  #print STDERR "TABLE DES POST PROCESSSED [$table]:" . Dumper( $des );

  bless $des, 'Decor::Core::Table::Description';
  hash_lock_recursive( $des );
  
  return $des;
}

#-----------------------------------------------------------------------------

sub describe_table
{
  my $table = uc shift;

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: table description cache hit for [$table]" );
    return $DES_CACHE{ 'TABLE_DES' }{ $table };
    }

  my $des = __load_table_des_hash( $table );

  $DES_CACHE{ 'TABLE_DES' }{ $table } = $des;
  
  return $des;
}

#-----------------------------------------------------------------------------

sub __preprocess_allow_deny
{
  my $hr = shift;

  for my $allow_deny ( qw( ALLOW DENY ) )
    {
    next unless exists $hr->{ $allow_deny };
    # $hr->{ $allow_deny } ||= [];
    my $access;
    for my $line ( @{ $hr->{ $allow_deny } } )
      {
      $access ||= {};
      my %a = __describe_parse_access_line( $line );
      %$access = ( %$access, %a );
      }
    $hr->{ $allow_deny } = $access;
    }
}

#-----------------------------------------------------------------------------

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
