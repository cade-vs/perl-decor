##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Describe;
use strict;
use open ':std', ':encoding(UTF-8)';

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
                      'CROSS'   => 1,
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

my %DES_KEY_VALUE_SHORTCUTS = (
                        'ADVISE' => {
                                    'UP'   => 'UPDATE',
                                    'INS'  => 'INSERT',
                                    'ED'   => 'ALL',
                                    'EDIT' => 'ALL',
                                    },
                        );

my %DES_CATEGORIES = (
                       '@'      => 1,
                       'TYPE'   => 1,
                       'FIELD'  => 1,
                       'INDEX'  => 1,
                       'FILTER' => 1,
                       'DO'     => 1,
                       'ACTION' => 1,
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
                      'GENERIC'  => 1,
                      'USER'     => 1,
                      'SESSION'  => 1,
                      'FILE'     => 1,
                      'MAP'      => 1,
                      'ENUM'     => 1,
                    );

# LEGEND: 1 == core attribute, must not have attribute path
#   NOTE: only type 1 attributes are filled with default values!
# LEGEND: 2 == regular attribute, it can have attribute path
# LEGEND: 3 == remote/path attribute, it must have attribute path
my %DES_ATTRS = (
                  '@' => {
                           REM         => 1, # remark, comment
                           
                           TYPE        => 1,
                           SCHEMA      => 1,
                           LABEL       => 1,
                           GRANT       => 1,
                           DENY        => 1,
                           SYSTEM      => 1,
                           READ_ONLY   => 1,
                           NO_COPY     => 1,
                           NO_PREVIEW  => 1,

                           ORDER_BY    => 1,
                           
                           VIRTUAL     => 1,

                           ON_INIT          => 1,
                           ON_RECALC        => 1,
                           ON_RECALC_INSERT => 1,
                           ON_RECALC_UPDATE => 1,
                           ON_INSERT        => 1,
                           ON_UPDATE        => 1,
                           
                           NO_AUTOCOMPLETE => 3, # disable interface autocomplete

                           VIEW_CUE    => 3,
                           INSERT_CUE  => 3, # related "INSERT NEW" button label
                           UPDATE_CUE  => 3, # related "UPDATE" button label
                           UPLOAD_CUE  => 3, # related "UPLOAD" button label
                           DELETE_CUE  => 3, # related "DELETE" button label
                           COPY_CUE    => 3, # related "DELETE" button label
                           
                           VIEW_LINK_CUE     => 3,
                           VIEW_ATTACHED_CUE => 3,
                           VIEW_DETACHED_CUE => 3,
                           INSERT_LINK_CUE   => 3,
                           UPDATE_LINK_CUE   => 3,
                           DETACH_LINK_CUE   => 3,
                           ATTACH_LINK_CUE   => 3,
                           UPLOAD_LINK_CUE   => 3,
                           DOWNLOAD_LINK_CUE => 3,
                           DOWNLOAD_FILE_CUE => 3,

                           PAGE_SIZE      => 3, # default page size for grid lists, if big enough, there will be no pagination
                           FIELDS_LIST    => 3, # fields to be shown
                           MASTER_FIELDS  => 3, # fields for display as master record
                           
                           RECORD_NAME => 3, # interpolated list of fields, describing current record

                           FTS          => 3, # enable interfaces to show FTS controls
                         },
                  'TYPE' => {
                           DETAILS      => 3,
                         },
                  'FIELD' => {
                           REM         => 1, # remark, comment
                           
                           TABLE        => 1,
                           NAME         => 1,

                           TYPE         => 1,
                           LABEL        => 2,
                           GRANT        => 1,
                           DENY         => 1,
                           SYSTEM       => 1, # field with all operations forbidden, only for system use
                           READ_ONLY    => 1, # field is visible but not allowed for modification
                           PRIMARY_KEY  => 1,
                           REQUIRED     => 1,
                           NOT_NULL     => 1,
                           UNIQUE       => 1,
                           INDEX        => 1,
                           BOOL         => 1,
                           PASSWORD     => 1,
                           FT           => 1, # filter, field transform, value modifier stack
                           INIT         => 1, # field initialization, initial value when insert

                           ON_INIT          => 1,
                           ON_RECALC        => 1,
                           ON_RECALC_INSERT => 1,
                           ON_RECALC_UPDATE => 1,
                           ON_INSERT        => 1,
                           ON_UPDATE        => 1,

                           MAXLEN       => 3, # max remote viewer field length
                           MONO         => 3, # remote viewer should use monospaced font
                           DETAILS      => 3,
                           OVERFLOW     => 3,
                           COMBO        => 3, # requires link selection to be combo
                           RADIO        => 3, # requires link selection to be radio
                           SEARCH       => 3, # incremental search for LINK fields
                           ORDERBY      => 3,
                           DISTINCT     => 3,
                           ROWS         => 3, # show more rows in views
                           EDITABLE     => 3, # if this field is allowed to be editable in views
                           GREP         => 3, # filtering grids by value will be case insensitive and LIKE-like
                           MULTI        => 3, # allow multiple select when filtering
                           DISPLAY      => 3, # advise display view, for example: web.display progress-bar

                           ADVISE      => 1, # takes arguments, INSERT,UPDATE,EDIT to be shown even if read-only on those screens
                          
                           HIDE_IF_EMPTY    => 3, # hide field if it is empty
                           NO_AUTOCOMPLETE  => 3, # disable interface autocomplete
                           RECALC_ON_CHANGE => 3, # recalc record form if field changes
                           
                           SELECT_FILTER_NAME => 3, # filter to be used on LINKED table
                           SELECT_FILTER_BIND => 3, # bind values from field in current table
                           
                           SECTION_NAME    => 3,
                           
                           VIEW_LINK_CUE     => 3,
                           VIEW_ATTACHED_CUE => 3,
                           VIEW_DETACHED_CUE => 3,
                           INSERT_LINK_CUE   => 3,
                           UPDATE_LINK_CUE   => 3,
                           DETACH_LINK_CUE   => 3,
                           ATTACH_LINK_CUE   => 3,
                           UPLOAD_LINK_CUE   => 3,
                           DOWNLOAD_LINK_CUE => 3,
                           
                           DIVIDER     => 3,

                           SHOW        => 3,
                           HIDE        => 3,
                           
                           DETAILS_FIELDS => 3,
                           DETAILS_LIMIT  => 3,
                           
                           BACKLINK_GRID_MODE => 3,
                           
                           OVERDUE      => 3, # instruct viewers to highlight overdue DATE and UTIME
                           
                           WLINK        => 1,
                           
                           ON_RECALC    => 1,
                           ON_INSERT    => 1,
                           ON_UPDATE    => 1,

                           FTS          => 1, # mark field for full text search indexing
                           
                           NO_HUMAN_FMT => 3, # do not use human formatting
                         },
                  'INDEX' => {
                           REM         => 1, # remark, comment
                           
                           FIELDS      => 1,
                           UNIQUE      => 1,
                           FIELDS      => 1,
                         },
                  'FILTER' => {
                           REM         => 1, # remark, comment
                           
                           SQL_WHERE   => 1,
                         },
                  'DO' => {
                           REM         => 1, # remark, comment
                           
                           LABEL       => 2,
                           GRANT       => 1,
                           DENY        => 1,
                           PRINT       => 3,
                           HIDE        => 3,
                         },
                  'ACTION' => {
                           REM         => 1, # remark, comment
                           
                           LABEL       => 1,
                           TARGET      => 1,
                           ICON        => 1,
                           GRANT       => 1,
                           DENY        => 1,
                         },
                );

my %COPY_CATEGORY_ATTRS = (
                          FIELD => {
                                   # nothing for now
                                   },
                          );

#my %DES_LINK_ATTRS = (
#                  'FIELD' => {
#                           GRANT  => 1,
#                           DENY   => 1,
#                         },
#                );

my %INLINE_METHODS = (
                     ON_INIT          => 1,
                     ON_RECALC        => 1,
                     ON_RECALC_INSERT => 1,
                     ON_RECALC_UPDATE => 1,
                     ON_INSERT        => 1,
                     ON_UPDATE        => 1,
                     );

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
  my $app_dir      = de_app_dir();
  my $bundles_dirs = de_bundles_dirs();

  my @dirs;
  push @dirs, "$root/core/tables";
  push @dirs, "$_/tables" for reverse @$bundles_dirs;
  push @dirs, "$app_dir/tables";

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

sub __fix_label_name
{
  my $name = shift;
  $name = uc( substr( $name, 0, 1 ) ) . lc( substr( $name, 1 ) );
  $name =~ s/_/ /;
  return $name;
}

sub __merge_table_des_file
{
  my $des    = shift; # config hash ref
  my $table  = shift;
  my $fname  = shift;
  my $opt    = shift || {};

  my $order = 0;

  my $inf;
  open( $inf, "<", $fname ) or boom "cannot open table description file [$fname]";

  de_log_debug2( "table description for [$table] open file: [$fname]" );

  my $sect_name = '@'; # self :) should be more like 0
  my $category  = '@';
  $des->{ $category }{ $sect_name } ||= {};
  push @{ $des->{ $category }{ $sect_name }{ '__DEBUG_ORIGIN' } }, "$fname at 0" if de_debug();
  $des->{ $category }{ $sect_name }{ 'NAME'  } = $table;
  $des->{ $category }{ $sect_name }{ 'LABEL' } = $table;
  $des->{ $category }{ $sect_name }{ 'TYPE'  } ||= 'GENERIC';
  my $file_mtime = file_mtime( $fname );
  if( $des->{ $category }{ $sect_name }{ '_MTIME' } < $file_mtime )
    {
    # of all files merged, keep only the latest modification time
    $des->{ $category }{ $sect_name }{ '_MTIME' } = $file_mtime;
    }

  my $field_templates = __load_table_raw_description( '_DE_TEMPLATES' ) unless $table eq '_DE_UNIVERSAL' or $table eq '_DE_TEMPLATES';

  my $ln; # line number
  while( my $line = <$inf> )
    {
    $ln++;
    my $origin = "$fname at $ln"; # localize $origin from the outer one

    chomp( $line );
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    last if $line =~ /^__(STATIC|END)__/;
    next unless $line =~ /\S/;       # skip whitespace
    next if $line =~ /^([#;]|\/\/)/; # skip comments
    de_log_debug2( "        line: [$line]" );

    if( $line =~ /^\s*=+\s*(([a-zA-Z_][a-zA-Z_0-9]*):\s*)?([a-zA-Z_][a-zA-Z_0-9]*)\s*(.*?)\s*$/ )
      {
      # new category item (section)
         $category  = uc( $2 || 'FIELD' );
         $sect_name = uc( $3 );
      my $sect_opts =     $4; # fixme: upcase/locase?

      boom "invalid category [$category] at [$fname at $ln]" unless exists $DES_CATEGORIES{ $category };

      de_log_debug2( "       =NEW SECTION: [$category:$sect_name]" );

      if( $table ne '_DE_UNIVERSAL' and $table ne '_DE_TEMPLATES' and exists $field_templates->{ $category }{ $sect_name } )
        {
        # copy template field definition if field name matches
        $des->{ $category }{ $sect_name } = { %{ $field_templates->{ $category }{ $sect_name } } };
        }

      $des->{ $category }{ $sect_name } ||= {};
      if( $category eq 'FIELD' )
        {
        # automatic names and labels are for FIELDS only
        $des->{ $category }{ $sect_name }{ 'NAME'   }   = $sect_name;
        $des->{ $category }{ $sect_name }{ 'LABEL'  } ||= __fix_label_name( $sect_name );
        $des->{ $category }{ $sect_name }{ '_ORDER' } = ++ $opt->{ '_ORDER' };
        }

# FIXME: 
#      if( exists $COPY_CATEGORY_ATTRS{ $category } )
#        {
#        $des->{ $category }{ $sect_name }{ $_ } = $des->{ '@' }{ '@' }{ $_ } for keys %{ $COPY_CATEGORY_ATTRS{ $category } };
#        }

      push @{ $des->{ $category }{ $sect_name }{ '__DEBUG_ORIGIN' } }, $origin if de_debug();

      next;
      }

    if( $line =~ /^\s*@(is)\s+([a-zA-Z_0-9]+)/i )
      {
      my $name = uc $2;
      $line = "\@isa _DE_$2 **";
      }

    if( $line =~ /^\s*@(isa|include)\s+([a-zA-Z_0-9]+)\s*(.*?)\s*$/i )
      {
      my $name = $2;
      my $args = $3; # options/arguments, FIXME: upcase/lowcase?

      de_log_debug2( "        \@ISA:  [$name] [$args]" );

      my $isa = __load_table_raw_description( $name );
      boom "\@isa/\@include error: cannot load config [$name] at [$fname at $ln]" unless $isa;

      my @args = split /[\s,]+/, uc $args;
      boom "\@isa/\@include error: empty argument list at [$fname at $ln]" unless @args;

      my $isa_copy_table_des = 0;
      my %isa_fields;

      for my $arg ( @args )
        {
        if( $arg eq '@' )
          {
          $isa_copy_table_des = 1;
          next;
          }
        
        if( $arg eq '**' )
          {
          $isa_copy_table_des = 1;
          $arg = '*';
          }

        if( $arg =~ s/^-// )
          {
          if( $arg =~ s/\*/\.*?/g )
            {
            delete $isa_fields{ $_ } for grep { $_ ne '_ID' } grep { /^$arg$/ } keys %{ $isa->{ 'FIELD' } };
            }
          else
            {
            delete $isa_fields{ $arg };
            }  
          }
        elsif( $arg =~ s/\*/\.*?/g )
          {
          $isa_fields{ $_ } = 1 for grep { /^$arg$/ } keys %{ $isa->{ 'FIELD' } };
          }
        else
          {
          $isa_fields{ $arg } = 1;
          }
        }
      delete $isa_fields{ '_ID' };
      my @isa_fields = sort { $isa->{ 'FIELD' }{ $a }{ '_ORDER' } <=> $isa->{ 'FIELD' }{ $b }{ '_ORDER' } } keys %isa_fields;

      if( $isa_copy_table_des )
        {
        while( my ( $k, $v ) = each %{ $isa->{ '@' }{ '@' } } )
          {
          next if $k =~ /^(NAME|LABEL)$/;
          $des->{ '@' }{ '@' }{ $k } = $v;
          }
        }

      for my $isa_field ( @isa_fields ) # FIXME: covers arg $opt
        {
        boom "\@isa/\@include error: cannot include unknown field [$isa_field] from [$name] at [$fname at $ln]" unless exists $isa->{ 'FIELD' }{ $isa_field };

        while( my ( $k, $v ) = each %{ $isa->{ 'FIELD' }{ $isa_field } } )
          {
          $des->{ 'FIELD' }{ $isa_field }{ $k } = $v;
          }
        
        $des->{ 'FIELD' }{ $isa_field }{ '_ORDER' } = ++ $opt->{ '_ORDER' };
        $des->{ 'FIELD' }{ $isa_field }{ '__ISA'  } = 1;
        }

      next;
      }
      
    if( $line =~ /^\s*@(remove)\s*(.*?)\s*$/i )
      {
      my $args = $2; # options/arguments, FIXME: upcase/lowcase?
      
      my @args = split /[\s,]+/, uc $args;

      boom "\@remove error: empty argument list at [$fname at $ln]" unless @args;

      for my $arg ( @args )
        {
        $arg =~ s/\*/\.*?/g;
        delete $des->{ 'FIELD' }{ $_ } for grep { $_ ne '_ID' } grep { /^$arg$/ } keys %{ $des->{ 'FIELD' } };
        }

      next;
      }

    if( $line =~ /^([a-zA-Z\-_0-9\.]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      $key =~ s/-/_/g;

      my $key_path;

      if( $key =~ /^(([A-Z_0-9]+\.)*)([A-Z_0-9]+)$/ )
        {
        $key_path = $1;
        $key = $3;
        }


      if( $key_path eq '' and ( exists $DE_TYPE_NAMES{ $key } or exists $DE_LTYPE_NAMES{ $key } ) )
        {
        $value = "$key $value";
        $key   = 'TYPE';
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
        boom "invalid DES_ATTR type >3, call maintainers :)";
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

      if( exists $DES_KEY_VALUE_SHORTCUTS{ $key } )
        {
        $value = exists $DES_KEY_VALUE_SHORTCUTS{ $key }{ uc $value } ? $DES_KEY_VALUE_SHORTCUTS{ $key }{ uc $value } : $value;
        }

      de_log_debug2( "            key:  [$sect_name]:[$key]=[$value]" );

      if( $key eq 'GRANT' or $key eq 'DENY' )
        {
        # special case
        if( $des->{ $category }{ $sect_name }{ '__ISA'  } and ! $des->{ $category }{ $sect_name }{ '__GRANT_DENY_NEW_POLICY'  } )
          {
          # if this is ISA section, it may bring ISA grant/deny. 
          # however if new grant/deny policy given in current table, old ones must be discarded
          # this must happen only once!
          delete $des->{ $category }{ $sect_name }{ '__GRANT_DENY_ACCUMULATOR' };     # grant/deny access accumulator array
                 $des->{ $category }{ $sect_name }{ '__GRANT_DENY_NEW_POLICY'  } = 1; # grant/deny new (local) policy, discard ISA one
          }

        push @{ $des->{ $category }{ $sect_name }{ '__GRANT_DENY_ACCUMULATOR' } }, "$key  $value";
        next;
        }

      if( $key eq 'READ_ONLY' )
        {
        $des->{ $category }{ $sect_name }{ '__GRANT_DENY_ACCUMULATOR' } = [ 'deny all', 'grant read' ];
        # leave it for further advise to viewers
        }
      if( $key eq 'SYSTEM' )
        {
        $des->{ $category }{ $sect_name }{ '__GRANT_DENY_ACCUMULATOR' } = [ 'deny all'               ];
        }
      if( $key eq 'REM' )
        {
        # remark, comment, holds array of all found REMs' values
        $des->{ $category }{ $sect_name }{ 'REM' } ||= [];
        push @{ $des->{ $category }{ $sect_name }{ 'REM' } }, $value;
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

      if( $key eq 'TYPE' and $table ne '_DE_UNIVERSAL' and $table ne '_DE_TEMPLATES' )
        {
        my $type = ( split /[,\s]+/, uc $value )[0];
        # copy template definition if field type matches
        my @attrs;
        push @attrs, %{ $field_templates->{ 'TYPE' }{ $type } } if exists $field_templates->{ 'TYPE' }{ $type };
        push @attrs, %{ $des->{ 'TYPE' }{ $type } }             if exists $des->{ 'TYPE' }{ $type };
        $des->{ $category }{ $sect_name } = { @attrs, %{ $des->{ $category }{ $sect_name } } } if @attrs;
        }

      next;
      }

    }
  close( $inf );

  return 1;
} # sub __merge_table_des_file

sub __merge_table_des_files
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
} # sub __merge_table_des_files

sub __postprocess_table_raw_description
{
  my $des   = shift;
  my $table = uc shift;
  #print STDERR "TABLE DES RAW [$table]($des):" . Dumper( $des );

  boom "missing description (load error) for table [$table]" unless $des;

  # postprocessing TABLE (self) ---------------------------------------------
  my @fields  = sort { $des->{ 'FIELD'  }{ $a }{ '_ORDER' } <=> $des->{ 'FIELD'  }{ $b }{ '_ORDER' } } keys %{ $des->{ 'FIELD'  } };
  my @indexes = sort { $des->{ 'INDEX'  }{ $a }{ '_ORDER' } <=> $des->{ 'INDEX'  }{ $b }{ '_ORDER' } } keys %{ $des->{ 'INDEX'  } };
  my @dos     = sort { $des->{ 'DO'     }{ $a }{ '_ORDER' } <=> $des->{ 'DO'     }{ $b }{ '_ORDER' } } keys %{ $des->{ 'DO'     } };
  my @actions = sort { $des->{ 'ACTION' }{ $a }{ '_ORDER' } <=> $des->{ 'ACTION' }{ $b }{ '_ORDER' } } keys %{ $des->{ 'ACTION' } };

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
  $des->{ '@' }{ '_ACTIONS_LIST' } = \@actions;
  $des->{ '@' }{ 'DSN'           } = uc( $des->{ '@' }{ 'DSN' } ) || 'MAIN';

  for my $method ( keys %INLINE_METHODS )
    {
    $des->{ '@' }{ "ON_$method"  } = [ grep { exists $des->{ 'FIELD' }{ $_ }{ "ON_$method" } } keys %{ $des->{ 'FIELD' } } ];
    }

#print STDERR "TABLE DES AFTER SELF PP [$table]:" . Dumper( $des, \@fields );
  # postprocessing FIELDs ---------------------------------------------------

  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    my $type_des = { %TYPE_ATTRS };
    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $fld_des->{ 'TYPE' };
    my $type = shift @type;

    my @debug_origin = exists $fld_des->{ '__ORIGIN' } ? @{ $fld_des->{ '__ORIGIN' } } : ();
    
    $fld_des->{ 'TABLE' } = $table;

    # "logic" types: LOCATION, EMAIL, etc.
    if( exists $DE_LTYPE_NAMES{ $type } )
      {
      $type_des->{ 'LNAME' } = $type;
      
      if( @type > 0 )
        {
        $type = $DE_LTYPE_NAMES{ $type }[0];
        }
      else  
        {
        @type = ( @{ $DE_LTYPE_NAMES{ $type } } );
        $type = shift @type;
        }
      }

    # "high" level types
    if( $type eq 'LINK' )
      {
      $fld_des->{ 'LINKED_TABLE' } = shift @type || boom "missing LINK TABLE in table [$table] field [$field] from [@debug_origin]";
      $fld_des->{ 'LINKED_FIELD' } = shift @type || 'NAME';
      #$fld_des->{ 'LINKED_FIELD' } = shift @type || boom "missing LINK FIELD in table [$table] field [$field] from [@debug_origin]";
      
      $fld_des->{ 'LINKED_TABLE' } = $table if uc $fld_des->{ 'LINKED_TABLE' } eq '%TABLE'; # self-link
      }
    elsif( $type eq 'BACKLINK' or $type eq 'BACK' )
      {
      $type = 'BACKLINK';
      $fld_des->{ 'BACKLINKED_TABLE' } = shift @type || boom "missing BACKLINK TABLE in table [$table] field [$field] from [@debug_origin]";
      $fld_des->{ 'BACKLINKED_KEY'   } = shift @type || boom "missing BACKLINK KEY   in table [$table] field [$field] from [@debug_origin]";
      $fld_des->{ 'BACKLINKED_SRC'   } = shift @type || '_ID';
      
      $fld_des->{ 'BACKLINKED_TABLE' } = $table if uc $fld_des->{ 'BACKLINKED_TABLE' } eq '%TABLE'; # self-backlink
      }
    if( $type eq 'WIDELINK' or $type eq 'WIDE' )
      {
      $type = 'WIDELINK';

      my $len = shift( @type ) || 128;
      $type_des->{ 'LEN' } = $len;
      }
    elsif( $type eq 'BOOL' )
      {
      $fld_des->{ 'BOOL' } = 1;

      $type = 'INT';
      @type = qw( 1 ); # length
      }
=pod
    elsif( $type eq 'FILE' )
      {
      $fld_des->{ 'LINKED_TABLE' } = 'DE_FILES';
      $fld_des->{ 'LINKED_FIELD' } = 'NAME';

      $type = 'LINK';
      }
=cut

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
    elsif( $type eq 'UTIME' or $type eq 'TIME' )
      {
      my $spec = shift( @type );
      my $dot = 0;
      if( $spec ne '' and $spec =~ /^\.(\d+)$/ )
        {
        $dot = $1;
        boom "invalid FIELD type SPEC [$spec] for type [$type] in table [$table] field [$field] from [@debug_origin] spec required range 0..9" unless $dot >= 0 and $dot <= 9;
        }
      $type_des->{ 'DOT' } = $dot;
      }

    $fld_des->{ 'TYPE' } = $type_des;

    # convert grant/deny list to access tree
#print STDERR "=====(GRANT DENY)==PRE+++ $table $field: " . Dumper( $des->{ 'FIELD' }{ $field } );

    if( exists $fld_des->{ '__GRANT_DENY_ACCUMULATOR' } )
      {
      describe_preprocess_grant_deny( $fld_des );
      }
    else
      {
      # add option to avoid this!
      $fld_des->{ 'GRANT' } ||= $des->{ '@' }{ 'GRANT' };
      $fld_des->{ 'DENY'  } ||= $des->{ '@' }{ 'DENY'  };
      }  

    # mark self inline methods list
    for my $im ( keys %INLINE_METHODS )
      {
      next unless exists $fld_des->{ $im };
      $des->{ '@' }{ $im }{ $field } = 1;
      }
    
#print STDERR "=====(GRANT DENY)==REZ+++ $table $field: " . Dumper( $fld_des );

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

  for my $act ( @actions )
    {
    describe_preprocess_grant_deny( $des->{ 'ACTION' }{ $act } );
    }

  # add empty keys to fields description before locking
  for my $category ( qw( FIELD INDEX FILTER DO ACTION ) )
    {
    next unless exists $des->{ $category };
    for my $key ( keys %{ $des->{ $category } })
      {
      for my $attr ( grep { $DES_ATTRS{ $category }{ $_ } < 3 } keys %{ $DES_ATTRS{ $category } } )
        {
        next if exists $des->{ $category }{ $key }{ $attr };
        $des->{ $category }{ $key }{ $attr } = undef;
        }
      # TODO: delete __GRANT_DENY_ACCUMULATOR unless $DEBUG  

      if( $BLESS_CATEGORIES{ $category } )
        {
        my $p = uc( substr( $category, 0, 1 ) ) . lc( substr( $category, 1 ) );
        bless $des->{ $category }{ $key }, "Decor::Core::Table::Category::${p}::Description";
        }
      }
    }

  # mark self inline methods list
  for my $im ( keys %INLINE_METHODS )
    {
    next unless exists $des->{ '@' }{ $im };
    $des->{ '@' }{ $im } = [ keys %{ $des->{ '@' }{ $im } } ];
    }

  # print STDERR "TABLE DES POST PROCESSSED [$table]($des):" . Dumper( $des );

  bless $des, 'Decor::Core::Table::Description';
  dlock $des;
  #hash_lock_recursive( $des );

#print STDERR "=====(FINAL) $table: " . Dumper( $des );

  return $des;
} # sub __postprocess_table_raw_description

#-----------------------------------------------------------------------------

sub __load_table_raw_description
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

  my  %des;
  tie %des, 'Tie::IxHash';

  my $opt = {};
  my $rc;
  $rc = __merge_table_des_files( \%des, '_DE_UNIVERSAL', $opt ) unless $table eq '_DE_UNIVERSAL' or $table eq '_DE_TEMPLATE'; # zero $rc for UNIVERSAL is ok
  $rc = __merge_table_des_files( \%des, $table,          $opt );
  return undef unless $rc > 0;
  
  $DES_CACHE{ 'TABLE_DES_RAW' }{ $table } = \%des;

  return \%des;
}

sub __check_table_des
{
  my $des = shift;

  my @fields  = keys %{ $des->{ 'FIELD' } };
  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    
    my $type  = $fld_des->{ 'TYPE' }{ 'NAME' };
    my $table = $fld_des->get_table_name();

    # "high" level types
    if( $type eq 'LINK' )
      {
      des_exists_boom( "in table $table field $field", $fld_des->{ 'LINKED_TABLE' }, $fld_des->{ 'LINKED_FIELD' } );
      }
    elsif( $type eq 'BACKLINK' )
      {
      des_exists_boom( "in table $table field $field", $fld_des->{ 'BACKLINKED_TABLE' }, $fld_des->{ 'BACKLINKED_KEY' } );
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

  my $des = __load_table_raw_description( $table );
  if( $des )
    {
    $des = dclone( $des );
    $des = __postprocess_table_raw_description( $des, $table );
    }
  else
    {
    my $tables_dirs = __get_tables_dirs();
    de_log( "error: cannot find/load description for table [$table] dirs [@$tables_dirs]" );
    return undef;
    }

  $DES_CACHE{ 'TABLE_DES' }{ $table } = $des;
  # NOTE! check MUST be done after TABLE_DES cache is filled with current table description!
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

  # TODO: clear TABLE_DES_RAW cache to free memory (well, not exactly)
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

  if( exists $hr->{ 'TYPE' } and ref( $hr->{ 'TYPE' } ) eq 'HASH' and exists $hr->{ 'TYPE' }{ 'NAME' } and $hr->{ 'TYPE' }{ 'NAME' } eq 'WIDELINK' )
    {
    # WIDELINKs are system and are forbidden for insert and update
    $hr->{ '__GRANT_DENY_ACCUMULATOR' } = [ @{ $hr->{ '__GRANT_DENY_ACCUMULATOR' } }, 'deny insert update'     ];
    }

  for my $line ( @{ $hr->{ '__GRANT_DENY_ACCUMULATOR' } } )
    {
    my ( $ty, $ta, $ac, $op )  = describe_parse_access_line( $line, $hr );

    for my $o ( @$op )
      {
      if( $ta )
        {
        # add mode, do not remove previous permissions
        $access{ $ty }{ $o } = [] unless defined $access{ $ty }{ $o };
        $access{ $ty }{ $o } = [ [ $access{ $ty }{ $o } ] ] unless ref( $access{ $ty }{ $o } );
        $ac->{ $o } = [ [ $ac->{ $o } ] ] unless ref( $ac->{ $o } );
        push @{ $access{ $ty }{ $o } }, @{ $ac->{ $o } };
        }
      else
        {  
        # set mode, remove previous permissions
        $access{ $ty }{ $o } = $ac->{ $o };
        }
      my $rty = { GRANT => 'DENY', DENY => 'GRANT' }->{ $ty };
      delete $access{ $rty }{ $o };
      }
    }
  $hr->{ 'GRANT' } = $access{ 'GRANT' };
  $hr->{ 'DENY'  } = $access{ 'DENY'  };

#  print Dumper( "describe_preprocess_grant_deny DEBUG:", $hr->{ 'NAME' }, $hr->{ '__GRANT_DENY_ACCUMULATOR' }, $hr->{ 'GRANT' }, $hr->{ 'DENY' } );
}

#-----------------------------------------------------------------------------

sub describe_parse_access_line
{
  my $line = uc shift;
  my $hr   = shift; # currently preprocessed field description, used for debug origin

  my @debug_origin = exists $hr->{ '__ORIGIN' } ? @{ $hr->{ '__ORIGIN' } } : ();

  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

  boom "invalid access line [$line] expected [grant|deny <op> <op> <op> to <grp>; <grp> + <grp>; <grp> + !<grp>] at [@debug_origin]"
        unless $line =~ /^\s*(GRANT|DENY)\s*((\+)?|\s)\s*(([A-Z_0-9]+\s*?)+?)(\s+TO\s+([A-Z0-9!+;,\s]+))?\s*$/;

  my $type_line   = $1;
  my $type_add    = $3;
  my $opers_line  = $4;
  my $groups_line = $6 ? $7 : 'ALL';
  $groups_line =~ s/\s*//g;

#print "ACCESS DEBUG LINE [$line] OPER [$opers_line] GROUPS [$groups_line]\n";
#  boom "invalid access line, keywords must not be separated by whitespace [$line]" if $line =~ /[a-z_0-9]\s+[a-z_0-9]/i;

#  $line =~ s/\s*//g;
#print "ACCESS DEBUG LINE [$line]\n";

###  my @line = split /[;,]/, $line;

###  my $ops = shift @line;
  my @opers  = split /[\s;,]+/, $opers_line;
  my @groups = split /\s*[;,]\s*/, $groups_line;

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
  return ( $type_line, $type_add, \%access, \@opers );
}

#-----------------------------------------------------------------------------

sub des_exists_boom
{
  my $msg = shift;
  boom "error: $msg: unknown TABLE:FIELD:ATTRIBUTE [@_]" unless des_exists( @_ );
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

  # FIXME: TODO: check logic?

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
