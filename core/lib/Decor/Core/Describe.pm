##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Describe;
use strict;

use Storable qw( dclone );
use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;
use Tie::IxHash;
use Data::Lock qw( dlock dunlock );

use Decor::Shared::Types;
use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;
#use Decor::Core::Config;
use Decor::Core::Table::Description;
use Decor::Core::Table::Category::Description;
use Decor::Core::Table::Category::Do::Description;
use Decor::Core::Table::Category::Field::Description;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
                des_reset

                des_get_tables_list
                describe_table
                describe_table_field
                preload_all_tables_descriptions

                des_exists
                des_exists_boom
                des_exists_category

                des_table_get_fields_list

                describe_parse_access_line
                describe_preprocess_grant_deny
                );

# TODO: FIXME: handle LOOP errors!

### TABLE DESCRIPTIONS #######################################################

my %OPERS = (
                      'READ'    => 1,
                      'INSERT'  => 1,
                      'UPDATE'  => 1,
                      'DELETE'  => 1,
                      'EXECUTE' => 1,
                      'ACCESS'  => 1,
                 );
my @OPERS = keys %OPERS;

my %GROUP_ALIASES = (
                      'ALL'    => 999,
                      'NOBODY' => 900,
                      'NOONE'  => 900,
                      'GUEST'  => 901,
);

my %TYPE_ATTRS = (
                      'NAME'   => undef,
                      'LEN'    => undef,
                      'DOT'    => undef,
                 );

my %DES_KEY_TYPES  = (
                      'GRANT'  => '@',
                      'DENY'   => '@',
                    );

my %DES_KEY_SHORTCUTS = (
                        'PKEY' => 'PRIMARY_KEY',
                        'REQ'  => 'REQUIRED',
                        'UNIQ' => 'UNIQUE',
                        'RO'   => 'READ_ONLY',
                        'SYS'  => 'SYSTEM',
                        );

my %DES_CATEGORIES = (
                       '@'      => 1,
                       'FIELD'  => 1,
                       'INDEX'  => 1,
                       'FILTER' => 1,
                       'DO'     => 1,
                     );

my %BLESS_CATEGORIES = (
                       'FIELD'  => 1,
                       'DO'     => 1,
                     );


my @TABLE_ATTRS = qw(
                      TYPE
                      SCHEMA
                      LABEL
                      GRANT
                      DENY
                    );

my %TABLE_TYPES = (
                      GENERIC  => 1,
                      USER     => 1,
                      SESSION  => 1,
                      FILE     => 1,
                    );

# LEGEND: 1 == core attribute, must not have attribute path
#   NOTE: only type 1 attributes are filled with default values!
# LEGEND: 2 == regular attribute, it can have attribute path
# LEGEND: 3 == remote/path attribute, it must have attribute path
my %DES_ATTRS = (
                  '@' => {
                           TYPE    => 1,
                           SCHEMA  => 1,
                           LABEL   => 1,
                           GRANT   => 1,
                           DENY    => 1,
                           SYSTEM  => 1,
                         },
                  'FIELD' => {
                           TABLE       => 1,
                           NAME        => 1,

                           TYPE        => 1,
                           LABEL       => 2,
                           GRANT       => 1,
                           DENY        => 1,
                           SYSTEM      => 1, # field with all operations forbidden, only for system use
                           READ_ONLY   => 1, # field is visible but not allowed for modification
                           PRIMARY_KEY => 1,
                           REQUIRED    => 1,
                           UNIQUE      => 1,
                           INDEX       => 1,
                           BOOL        => 1,
                           PASSWORD    => 1,

                           MAXLEN      => 3, # max remote viewer field length
                           MONO        => 3, # remote viewer should use monospaced font
                           DETAILS     => 3,
                           OVERFLOW    => 3,
                           COMBO       => 3, # requires link selection to be combo
                           
                           SELECT_FILTER => 3,
                         },
                  'INDEX' => {
                           FIELDS      => 1,
                           UNIQUE      => 1,
                           FIELDS      => 1,
                         },
                  'FILTER' => {
                           SQL_WHERE   => 1,
                         },
                  'DO' => {
                           LABEL       => 2,
                           GRANT       => 1,
                           DENY        => 1,
                         },
                );

#my %DES_LINK_ATTRS = (
#                  'FIELD' => {
#                           GRANT  => 1,
#                           DENY   => 1,
#                         },
#                );

#my %TABLE_ATTRS = map { $_ => 1 } @TABLE_ATTRS;
#hash_lock_recursive( \%TABLE_ATTRS );
#my %FIELD_ATTRS = map { $_ => 1 } @FIELD_ATTRS;
#hash_lock_recursive( \%FIELD_ATTRS );

#-----------------------------------------------------------------------------

my %DES_CACHE;
my $DES_CACHE_PRELOADED;

sub des_reset
{
  %DES_CACHE = ();
  $DES_CACHE_PRELOADED = 0;

  return 1;
}

#-----------------------------------------------------------------------------

sub __get_tables_dirs
{
  return $DES_CACHE{ 'TABLES_DIRS_AR' } if exists $DES_CACHE{ 'TABLES_DIRS_AR' };

  my $root         = de_root();
  my $app_path     = de_app_path();
  my $bundles_dirs = de_bundles_dirs();

  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @$bundles_dirs;
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
    #print STDERR "$dir/*.def\n";
    push @tables, ( sort( glob_tree( "$dir/*.def" ) ) );
    }

  s/^.*?\/([^\/]+)\.def$/uc($1)/ie for @tables;
  @tables = keys %{ { map { $_ => 1 } grep { ! /^_+/ } @tables } };

  $DES_CACHE{ 'TABLES_LIST_AR' } = \@tables;

  return \@tables;
}

#-----------------------------------------------------------------------------

sub __merge_table_des_file
{
  my $des    = shift; # config hash ref
  my $table  = shift;
  my $fname  = shift;
  my $opt    = shift || {};

  my $order = 0;

  my $inf;
  open( $inf, $fname ) or boom "cannot open table description file [$fname]";

  de_log_debug( "table description open file: [$fname]" );

  my $sect_name = '@'; # self :) should be more like 0
  my $category  = '@';
  $des->{ $category }{ $sect_name } ||= {};
  push @{ $des->{ $category }{ $sect_name }{ '__DEBUG_ORIGIN' } }, $fname;
  $des->{ $category }{ $sect_name }{ 'NAME' } = $table;
  $des->{ $category }{ $sect_name }{ 'TYPE' } = 'GENERIC';
  my $file_mtime = file_mtime( $fname );
  if( $des->{ $category }{ $sect_name }{ '_MTIME' } < $file_mtime )
    {
    # of all files merged, keep only the latest modification time
    $des->{ $category }{ $sect_name }{ '_MTIME' } = $file_mtime;
    }

  my $ln; # line number
  while( my $line = <$inf> )
    {
    $ln++;
    my $origin = "$fname at $ln"; # localize $origin from the outer one

    chomp( $line );
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    next unless $line =~ /\S/;
    next if $line =~ /^([#;]|\/\/)/;
    de_log_debug2( "        line: [$line]" );

    if( $line =~ /^\s*=+\s*(([a-zA-Z_][a-zA-Z_0-9]*):\s*)?([a-zA-Z_][a-zA-Z_0-9]*)\s*(.*?)\s*$/ )
      {
         $category  = uc( $2 || 'FIELD' );
         $sect_name = uc( $3 );
      my $sect_opts =     $4; # fixme: upcase/locase?

      boom "invalid category [$category] at [$fname at $ln]" unless exists $DES_CATEGORIES{ $category };

      de_log_debug2( "       =sect: [$category:$sect_name]" );

      $des->{ $category }{ $sect_name } ||= {};
      $des->{ $category }{ $sect_name }{ 'TABLE' }   = $table;
      $des->{ $category }{ $sect_name }{ 'NAME'  }   = $sect_name;
      $des->{ $category }{ $sect_name }{ 'LABEL' } ||= $sect_name;
      # FIXME: URGENT: copy only listed keys! no all
###      %{ $config->{ $category }{ $sect_name } } = ( %{ dclone( $config->{ '@' }{ '@' } ) }, %{ $config->{ $category }{ $sect_name } } );
      $des->{ $category }{ $sect_name }{ '__GDA'  } = [ @{ $des->{ '@' }{ '@' }{ '__GDA'  } || [] } ];


      $des->{ $category }{ $sect_name }{ '_ORDER' } = ++ $opt->{ '_ORDER' };

      if( de_debug() )
        {
        $des->{ $category }{ $sect_name }{ '__DEBUG_ORIGIN' } ||= [];
        push @{ $des->{ $category }{ $sect_name }{ '__DEBUG_ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^@(isa|include)\s*([a-zA-Z_0-9]+)\s*(.*?)\s*$/ )
      {
      my $name = $2;
      my $args = $3; # options/arguments, FIXME: upcase/lowcase?

      de_log_debug2( "        isa:  [$name][$args]" );

      my $isa = __load_table_description( $name );

#print STDERR Dumper( "my isa = __load_table_description( $name );", $isa );

      boom "isa/include error: cannot load config [$name] at [$fname at $ln]" unless $isa;

      my @args = split /[\s,]+/, uc $args;

      boom "isa/include error: empty argument list at [$fname at $ln]" unless @args;

      my %isa_args;
      tie %isa_args, 'Tie::IxHash';

      for my $arg ( @args )
        {
        if( $arg eq '**' )
          {
          $isa_args{ '@' } = 1;
          $arg = '*';
          }

        if( $arg eq '*' )
          {
          $isa_args{ $_ } = 1 for sort { $isa->{ 'FIELD' }{ $a }{ '_ORDER' } <=> $isa->{ 'FIELD' }{ $b }{ '_ORDER' } } keys %{ $isa->{ 'FIELD' } };
          }
        elsif( $arg =~ s/^-// )
          {
          delete $isa_args{ $arg };
          }
        else
          {
          $isa_args{ $arg } = 1;
          }
        }
      @args = keys %isa_args;

#      if( $args[0] eq '*' )
#        {
#        shift @args;
#        unshift @args, sort { $isa->{ 'FIELD' }{ $a }{ '_ORDER' } <=> $isa->{ 'FIELD' }{ $b }{ '_ORDER' } } keys %{ $isa->{ 'FIELD' } };
#        }

#      de_log_debug( "        isa:  DUMP: " . Dumper($isa,\@args) );
#print Dumper( 'isa - ' x 10, $isa,\@args);

      for my $arg ( @args ) # FIXME: covers arg $opt
        {
###        boom "isa/include error: key [*] can appear only at first position inside arguments list in [$name] at [$fname at $ln]" if $arg eq '*';
        my $isa_category;
        my $isa_sect_name;
        if( $arg =~ /(([a-zA-Z_][a-zA-Z_0-9]*):)?([a-zA-Z_][a-zA-Z_0-9]*|\@)/ )
          {
          #$isa_category  = uc( $2 || $opt->{ 'DEFAULT_CATEGORY' } || '*' );
          $isa_category  = uc( $2 || 'FIELD' || '*' );
          $isa_sect_name = uc( $3 );
          }
        else
          {
          boom "isa/include error: invalid key [$arg] in [$name] at [$fname at $ln]";
          }

        $isa_category = '@' if $isa_sect_name eq '@';
#        if( $category ne $isa_category )
#          {
#          boom "isa/include error: cannot inherit kyes from different categories, got [$isa_category] expected [$category] key [$arg] in [$name] at [$fname at $ln]";
#          }
        boom "isa/include error: cannot include unknown key [$arg] from [$name] at [$fname at $ln]" if ! exists $isa->{ $isa_category } or ! exists $isa->{ $isa_category }{ $isa_sect_name };
        $des->{ $isa_category }{ $isa_sect_name } ||= {};

#print STDERR Dumper( 'isa - ' x 10, $isa_category, $isa_sect_name, $isa->{ $isa_category }{ $isa_sect_name });

        %{ $des->{ $isa_category }{ $isa_sect_name } } = (
                                                         %{         $des->{ $isa_category }{ $isa_sect_name }   },
                                                         %{ dclone( $isa->{ $isa_category }{ $isa_sect_name } ) },
                                                         );
        $des->{ $category }{ $sect_name }{ '_ORDER' } = ++ $opt->{ '_ORDER' };
        $des->{ $isa_category }{ $isa_sect_name }{ '__ISA'  } = 1;
        }

      next;
      }

    if( $line =~ /^([a-zA-Z_0-9\.]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      my $key_path;

      if( $key =~ /^(([A-Z_0-9]+\.)*)([A-Z_0-9]+)$/ )
        {
        $key_path = $1;
        $key = $3;
        }

      my $error_location = "[$key_path$key] for table [$table] category [$category] section [$sect_name] at [$fname at $ln]";

      $key = $DES_KEY_SHORTCUTS{ $key } if exists $DES_KEY_SHORTCUTS{ $key };
      boom "unknown attribute key $error_location" unless exists $DES_ATTRS{ $category }{ $key };

      my $attr_type = $DES_ATTRS{ $category }{ $key };

      if( $attr_type == 1 and $key_path ne '' )
        {
        boom "core attribute must not have path key $error_location";
        }
      elsif( $attr_type == 3 and $key_path eq '' )
        {
        boom "remote/path attributes must have path key $error_location";
        }
      elsif( $attr_type >= 4 )
        {
        boom "invalid DES_ATTR type >3, call maintainers";
        }

      $key = "$key_path$key"; # after checks and shortcuts bring back key full name

      if( $value =~ /^(['"])(.*?)\1/ )
        {
        $value = $2;
        }
      elsif( $value eq '' )
        {
        $value = 1;
        }

      de_log_debug2( "            key:  [$sect_name]:[$key]=[$value]" );

      if( $key eq 'GRANT' or $key eq 'DENY' )
        {
        # special case
        if( $des->{ $category }{ $sect_name }{ '__ISA'  } and ! $des->{ $category }{ $sect_name }{ '__GDL'  } )
          {
          delete $des->{ $category }{ $sect_name }{ '__GDA'  };     # grant/deny access accumulator array
                 $des->{ $category }{ $sect_name }{ '__GDL'  } = 1; # grant/deny local policy, discard ISA one
          }

        push @{ $des->{ $category }{ $sect_name }{ '__GDA' } }, "$key  $value";
        next;
        }

      if( $DES_KEY_TYPES{ $key } eq '@' )
        {
        $des->{ $category }{ $sect_name }{ $key } ||= [];
        push @{ $des->{ $category }{ $sect_name }{ $key } }, $value;
        }
      else
        {
        $des->{ $category }{ $sect_name }{ $key } = $value;
        }

      next;
      }


    }
  close( $inf );

  return 1;
}

sub __merge_table_des_hash
{
  my $des   = shift;
  my $table = uc shift;
  my $opt   = shift || {};

  boom "invalid TABLE name [$table]" unless de_check_name( $table );

  my $tables_dirs = __get_tables_dirs();

  #print STDERR 'TABLE DES DIRS:' . Dumper( $tables_dirs );

  my $table_fname = lc $table;
  my @table_files;
  push @table_files, glob_tree( "$_/$table_fname.def" ) for @$tables_dirs;

  my $c = 0;
  for my $file ( @table_files )
    {
    $c++;
    __merge_table_des_file( $des, $table, $file, $opt );
    }

  return $c;
}

sub __postprocess_table_des_hash
{
  my $des   = shift;
  my $table = uc shift;
###  print STDERR "TABLE DES RAW [$table]:" . Dumper( $des );

  boom "missing description (load error) for table [$table]" unless $des;

  # postprocessing TABLE (self) ---------------------------------------------
  my @fields  = sort { $des->{ 'FIELD' }{ $a }{ '_ORDER' } <=> $des->{ 'FIELD' }{ $b }{ '_ORDER' } } keys %{ $des->{ 'FIELD' } };
  my @indexes = sort { $des->{ 'INDEX' }{ $a }{ '_ORDER' } <=> $des->{ 'INDEX' }{ $b }{ '_ORDER' } } keys %{ $des->{ 'INDEX' } };
  my @dos     = sort { $des->{ 'INDEX' }{ $a }{ '_ORDER' } <=> $des->{ 'INDEX' }{ $b }{ '_ORDER' } } keys %{ $des->{ 'DO'    } };

  # move table config in more comfortable location
  $des->{ '@' } = $des->{ '@' }{ '@' };

  # check table type
  $des->{ '@' }{ 'TYPE' } = uc $des->{ '@' }{ 'TYPE' };
  if( ! exists $TABLE_TYPES{ $des->{ '@' }{ 'TYPE' } } )
    {
    my $ttype = $des->{ '@' }{ 'TYPE' };
    my @ttype = keys %TABLE_TYPES;
    boom "unknown type [$ttype] for table [$table], expected one of (@ttype)";
    }

  # convert grant/deny list to access tree
  describe_preprocess_grant_deny( $des->{ '@' } );

  # add empty keys to table description before locking
  for my $attr ( keys %{ $DES_ATTRS{ '@' } } )
    {
    next if exists $des->{ '@' }{ $attr };
    $des->{ '@' }{ $attr } = undef;
    }

  # more postprocessing work
  $des->{ '@' }{ '_TABLE_NAME'   } = $table;
  $des->{ '@' }{ '_FIELDS_LIST'  } = \@fields;
  $des->{ '@' }{ '_INDEXES_LIST' } = \@indexes;
  $des->{ '@' }{ '_DOS_LIST'     } = \@dos;
  $des->{ '@' }{ 'DSN'           } = uc( $des->{ '@' }{ 'DSN' } ) || 'MAIN';

  $des->{ '@' }{ 'GRANT' } = {} unless $des->{ '@' }{ 'GRANT' };
  $des->{ '@' }{ 'DENY'  } = {} unless $des->{ '@' }{ 'DENY'  };

###  print STDERR "TABLE DES AFTER SELF PP [$table]:" . Dumper( $des );
  # postprocessing FIELDs ---------------------------------------------------

  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    my $type_des = { %TYPE_ATTRS };
    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $fld_des->{ 'TYPE' };
    my $type = shift @type;

    my @debug_origin = exists $fld_des->{ '__DEBUG_ORIGIN' } ? @{ $fld_des->{ '__DEBUG_ORIGIN' } } : ();

    # "high" level types
    if( $type eq 'LINK' )
      {
      $fld_des->{ 'LINKED_TABLE' } = shift @type || boom "missing LINK TABLE in table [$table] field [$field] from [@debug_origin]";
      $fld_des->{ 'LINKED_FIELD' } = shift @type || boom "missing LINK FIELD in table [$table] field [$field] from [@debug_origin]";;
      }
    elsif( $type eq 'BACKLINK' )
      {
      $fld_des->{ 'BACKLINKED_TABLE' } = shift @type || boom "missing BACKLINK TABLE in table [$table] field [$field] from [@debug_origin]";;
      $fld_des->{ 'BACKLINKED_KEY'   } = shift @type || boom "missing BACKLINK KEY   in table [$table] field [$field] from [@debug_origin]";;
      }
    elsif( $type eq 'BOOL' )
      {
      $fld_des->{ 'BOOL' } = 1;

      $type = 'INT';
      @type = qw( 1 ); # length
      }
    elsif( $type eq 'FILE' )
      {
      $fld_des->{ 'LINKED_TABLE' } = 'DE_FILES';
      $fld_des->{ 'LINKED_FIELD' } = 'NAME';

      $type = 'LINK';
      }

    boom "invalid FIELD TYPE [$type] in table [$table] field [$field] from [@debug_origin]" unless exists $DE_TYPE_NAMES{ $type };

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
      $spec = '.4' if $spec eq ''; # default spec, FIXME: get from config?
      if( $spec ne '' and $spec =~ /^(\d*)(\.(\d*))?$/ )
        {
        my $len = $1;
        my $dot = $3;
        if( $len == 0 )
          {
          if( $dot > 0 )
            {
            $len = 18 + $dot;
            }
          else
            {
            $len = 18 + 18;
            $dot =      18;
            }
          }
        $type_des->{ 'LEN' } = $len if $len > 0;
        $type_des->{ 'DOT' } = $dot if $dot ne '';
        }
      else
        {
        boom "invalid FIELD type SPEC [$spec] for type [$type] in table [$table] field [$field] from [@debug_origin]";
        }
      }
    $fld_des->{ 'TYPE' } = $type_des;

    # convert grant/deny list to access tree
#print STDERR "=====(GRANT DENY)==PRE+++ $table $field: " . Dumper( $des->{ 'FIELD' }{ $field } );
    describe_preprocess_grant_deny( $des->{ 'FIELD' }{ $field } );
#print STDERR "=====(GRANT DENY)==REZ+++ $table $field: " . Dumper( $des->{ 'FIELD' }{ $field } );

    # FIXME: more categories INDEX: ACTION: etc.
    # inherit empty keys
    #for my $attr ( keys %{ $DES_LINK_ATTRS{ 'FIELD' } } )
    #  {
    #  next if exists $des->{ 'FIELD' }{ $field }{ $attr };
    #  # link missing attributes to self
    #  $des->{ 'FIELD' }{ $field }{ $attr } = $des->{ '@' }{ $attr };
    #  }
=pod
    for my $grant_deny ( qw( GRANT DENY ) )
      {
      
      next;
      for my $oper ( keys %{ $des->{ '@' }{ $grant_deny } } )
        {
        next if exists $des->{ 'FIELD' }{ $field }{ $grant_deny }{ $oper };
        # link missing operation grant/deny to self
        $des->{ 'FIELD' }{ $field }{ $grant_deny }{ $oper } = $des->{ '@' }{ $grant_deny }{ $oper }
        }
      }
=cut      
#print STDERR "=====(GRANT DENY)==REZZZZ+++ $table $field: " . Dumper( $des->{ 'FIELD' }{ $field } );

    }

  for my $do ( @dos )
    {
    describe_preprocess_grant_deny( $des->{ 'DO' }{ $do } );
    }

  # add empty keys to fields description before locking
  for my $category ( qw( FIELD INDEX FILTER DO ) )
    {
    next unless exists $des->{ $category };
    for my $key ( keys %{ $des->{ $category } })
      {
      for my $attr ( grep { $DES_ATTRS{ $category }{ $_ } < 3 } keys %{ $DES_ATTRS{ $category } } )
        {
        next if exists $des->{ $category }{ $key }{ $attr };
        $des->{ $category }{ $key }{ $attr } = undef;
        }
      # TODO: delete __GDA unless $DEBUG  

      if( $BLESS_CATEGORIES{ $category } )
        {
        my $p = uc( substr( $category, 0, 1 ) ) . lc( substr( $category, 1 ) );
        bless $des->{ $category }{ $key }, "Decor::Core::Table::Category::${p}::Description";
        }
      }
    }

  #print STDERR "TABLE DES POST PROCESSSED [$table]:" . Dumper( $des );

  bless $des, 'Decor::Core::Table::Description';
  dlock $des;
  #hash_lock_recursive( $des );

  return $des;
}

#-----------------------------------------------------------------------------

sub __load_table_description
{
  my $table = uc shift;

  if( exists $DES_CACHE{ 'TABLE_DES_RAW' }{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: table description cache hit for [$table]" );
    return $DES_CACHE{ 'TABLE_DES_RAW' }{ $table };
    }
  elsif( $DES_CACHE_PRELOADED )
    {
    # table must be loaded, if here, then something wrong did happen :)
    return undef;
    }

  my $des = {};
  tie %$des, 'Tie::IxHash';

  my $opt = {};
  my $rc;
  $rc = __merge_table_des_hash( $des, '_DE_UNIVERSAL', $opt ) unless $table eq '_DE_UNIVERSAL';
  # zero $rc for UNIVERSAL is ok
  $rc = __merge_table_des_hash( $des, $table, $opt );
  return undef unless $rc > 0;

  $DES_CACHE{ 'TABLE_DES_RAW' }{ $table } = $des;

  return $des;
}

sub __check_table_des
{
  my $des = shift;

  my @fields  = keys %{ $des->{ 'FIELD' } };
  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    
    my $type = $fld_des->{ 'TYPE' }{ 'NAME' };

    # "high" level types
    if( $type eq 'LINK' )
      {
      des_exists_boom( $fld_des->{ 'LINKED_TABLE' }, $fld_des->{ 'LINKED_FIELD' } );
      }
    elsif( $type eq 'BACKLINK' )
      {
      des_exists_boom( $fld_des->{ 'BACKLINKED_TABLE' }, $fld_des->{ 'BACKLINKED_KEY' } );
      }
    }
}
#-----------------------------------------------------------------------------

sub describe_table
{
  my $table = uc shift;

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table } )
    {
    return $DES_CACHE{ 'TABLE_DES' }{ $table };
    }
  elsif( $DES_CACHE_PRELOADED )
    {
    # table must be loaded, if here, then something wrong did happen :)
    my $tables_dirs = __get_tables_dirs();
    boom "missing preload description for table [$table] dirs [@$tables_dirs]";
    }

  my $des = __load_table_description( $table );

  if( $des )
    {
    __postprocess_table_des_hash( $des, $table );
    }
  else
    {
    my $tables_dirs = __get_tables_dirs();
    boom "cannot find/load description for table [$table] dirs [@$tables_dirs]";
    }

  $DES_CACHE{ 'TABLE_DES' }{ $table } = $des;
  # NOTE! check MUST be done after TABLE_DES cache is filled with current table!
  __check_table_des( $des );

#print STDERR "describe_table [$table] " . Dumper( $des );

  return $des;
}

#-----------------------------------------------------------------------------

sub preload_all_tables_descriptions
{
  my $tables = des_get_tables_list();

  for my $table ( @$tables )
    {
    de_log_debug( "preloading description for table [$table]" );
    describe_table( $table );
    };

  # TODO: clear TABLE_DES_RAW cache to free memory
  delete $DES_CACHE{ 'TABLE_DES_RAW' };

  $DES_CACHE_PRELOADED = 1;
}

#-----------------------------------------------------------------------------

sub describe_table_field
{
  my $table = shift;
  my $field = shift;

  my $des = describe_table( $table );
  return $des->get_table_des() if $field eq '@'; # shortcut to self
  return $des->get_field_des( $field );
}

#-----------------------------------------------------------------------------

sub describe_preprocess_grant_deny
{
  my $hr = shift;

  my %access = ( 'GRANT' => {}, 'DENY' => {} );

  $hr->{ '__GDA' } = [ 'deny all', 'grant read' ] if $hr->{ 'READ_ONLY' };
  $hr->{ '__GDA' } = [ 'deny all'               ] if $hr->{ 'SYSTEM'    };

  for my $line ( @{ $hr->{ '__GDA' } } )
    {
    my ( $ty, $ac, $op )  = describe_parse_access_line( $line, $hr );
    for my $o ( @$op )
      {
      $access{ $ty }{ $o } = $ac->{ $o };
      my $rty = { GRANT => 'DENY', DENY => 'GRANT' }->{ $ty };
      delete $access{ $rty }{ $o };
      }
    }
  $hr->{ 'GRANT' } = $access{ 'GRANT' };
  $hr->{ 'DENY'  } = $access{ 'DENY'  };

  #print Dumper( "describe_preprocess_grant_deny DEBUG:", $hr->{ 'NAME' }, $hr->{ '__GDA' }, $hr->{ 'GRANT' }, $hr->{ 'DENY' } );
}

#-----------------------------------------------------------------------------

sub describe_parse_access_line
{
  my $line = uc shift;
  my $hr   = shift; # currently preprocessed field description, used for debug origin

  my @debug_origin = exists $hr->{ '__DEBUG_ORIGIN' } ? @{ $hr->{ '__DEBUG_ORIGIN' } } : ();

  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

  boom "invalid access line [$line] expected [grant|deny <op> <op> <op> to <grp>; <grp> + <grp>; <grp> + !<grp>] at [@debug_origin]"
        unless $line =~ /^\s*(GRANT|DENY)\s+(([A-Z_0-9]+\s*?)+?)(\s+TO\s+([A-Z0-9!+;\s]+))?\s*$/;

  my $type_line   = $1;
  my $opers_line  = $2;
  my $groups_line = $4 ? $5 : 'ALL';
  $groups_line =~ s/\s*//g;

#print "ACCESS DEBUG LINE [$line] OPER [$opers_line] GROUPS [$groups_line]\n";
#  boom "invalid access line, keywords must not be separated by whitespace [$line]" if $line =~ /[a-z_0-9]\s+[a-z_0-9]/i;

#  $line =~ s/\s*//g;
#print "ACCESS DEBUG LINE [$line]\n";

  my @line = split /;/, $line;

  my $ops = shift @line;
  my @opers  = split /\s+/, $opers_line;
  my @groups = split /\s*[;]\s*/, $groups_line;

  $_ = $GROUP_ALIASES{ $_ } || $_ for @groups;

  for my $op ( @opers )
    {
    if( $op eq 'ALL' )
      {
      @opers = @OPERS;
      last;
      }
    if( ! $OPERS{ $op } )
      {
      de_log( "error: unknown operation [$op] in line [$line] at one of [@debug_origin]" );
      next;
      }
    }

  my %access;

  for my $op ( @opers )
    {
    if( @groups == 1 and $groups[ 0 ] > 0 )
      {
      $access{ uc $op } = $groups[ 0 ];
      }
    else
      {
      $access{ uc $op } = [ map { [ split /[+]/ ] } @groups ];
      }
    }


#print Dumper( $line, $opers_line, $groups_line, \%access );
  return ( $type_line, \%access, \@opers );
}

#-----------------------------------------------------------------------------

sub des_exists_boom
{
  boom "unknown table|field|attribute [@_]" unless des_exists( @_ );
}

sub des_exists
{
  return des_exists_category( 'FIELD', @_ );
}

sub des_exists_category
{
  my $category = uc shift;
  boom "invalid category [$category]" unless exists $DES_CATEGORIES{ $category };
  boom "invalid number of arguments, expected (table,field,attr)" unless @_ > 0 and @_ < 4;

  my $table = $_[0];

  return 0 unless de_check_name( $table );

  # check/load table
  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table } )
    {
    # table exists and is loaded, no fields given
    return 1 if @_ == 1;
    }
  elsif( $DES_CACHE_PRELOADED )
    {
    # table does not exists and all tables are loaded already
    return 0;
    }
  else
    {
    # table not loaded, unsure if exists
    my $des = describe_table( $table );
    return 1 if   $des and @_ == 1;
    return 0 if ! $des;
    }

  # table exists, but field check is expected
  my $field = $_[1];
  return 0 unless de_check_name( $field );
  
  return 0 unless exists $DES_CACHE{ 'TABLE_DES' }{ $table }{ $category };

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table }{ $category }{ $field } )
    {
    return 2 if @_ == 2;
    }
  else
    {
    return 0;
    }

  # table and field exist, but attribute check is expected
  my $attr = $_[2];

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table }{ $category }{ $field }{ $attr } )
    {
    return 3 if @_ == 3;
    }
  else
    {
    return 0;
    }

  return 0; # catch-all, should be unreachable
}

#--- helpers -----------------------------------------------------------------

sub des_table_get_fields_list
{
  my $table = shift;

  my $des = describe_table( $table );
  return $des->get_fields_list();
}

### EOF ######################################################################
1;
