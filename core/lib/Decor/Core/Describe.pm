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
use Tie::IxHash;
use Data::Lock qw( dlock dunlock );

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Log;
#use Decor::Core::Config;
use Decor::Core::Table::Description;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                des_reset
                
                des_get_tables_list
                describe_table 
                describe_table_field
                preload_all_tables_descriptions

                des_exists
                );

### TABLE DESCRIPTIONS #######################################################

my %TYPE_ATTRS = (
                      'NAME' => undef,
                      'LEN'  => undef,
                      'DOT'  => undef,
                 );

my %DES_KEY_TYPES  = (
                      'ALLOW' => '@',
                      'DENY'  => '@',
                    );

my %DES_KEY_SHORTCUTS = (
                        'PKEY' => 'PRIMARY_KEY',
                        'REQ'  => 'REQUIRED',
                        'UNIQ' => 'UNIQUE',
                        );
                    
my %DES_CATEGORIES = ( 
                       '@'     => 1, 
                       'FIELD' => 1,  
                       'INDEX' => 1 
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
                           SYSTEM => 1,
                         },
                  'FIELD' => {
                           TYPE        => 1,
                           LABEL       => 1,
                           ALLOW       => 1,
                           DENY        => 1,
                           SYSTEM      => 1,
                           PRIMARY_KEY => 1,
                           REQUIRED    => 1,
                           UNIQUE      => 1,
                           INDEX       => 1,
                         },
                  'INDEX' => {
                           FIELDS      => 1,
                           UNIQUE      => 1,
                           FIELDS      => 1,
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
    my $origin = "$fname:$ln"; # localize $origin from the outer one

    chomp( $line );
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    next unless $line =~ /\S/;
    next if $line =~ /^([#;]|\/\/)/;
    de_log_debug( "        line: [$line]" );  

    if( $line =~ /^=(([a-zA-Z_][a-zA-Z_0-9]*):\s*)?([a-zA-Z_][a-zA-Z_0-9]*)\s*(.*?)\s*$/ )
      {
         $category  = uc( $2 || 'FIELD' );    
         $sect_name = uc( $3 );
      my $sect_opts =     $4; # fixme: upcase/locase?

      boom "invalid category [$category] at [$fname:$ln]" unless exists $DES_CATEGORIES{ $category };

      de_log_debug( "       =sect: [$category:$sect_name]" );  
      
      $des->{ $category }{ $sect_name } ||= {};
      $des->{ $category }{ $sect_name }{ 'LABEL' } ||= $sect_name;
      # FIXME: URGENT: copy only listed keys! no all
###      %{ $config->{ $category }{ $sect_name } } = ( %{ dclone( $config->{ '@' }{ '@' } ) }, %{ $config->{ $category }{ $sect_name } } );
      $des->{ $category }{ $sect_name }{ '_ORDER' } = ++ $opt->{ '_ORDER' };
      
      if( de_debug() )
        {
        $des->{ $category }{ $sect_name }{ 'DEBUG::ORIGIN' } ||= [];
        push @{ $des->{ $category }{ $sect_name }{ 'DEBUG::ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^@(isa|include)\s*([a-zA-Z_0-9]+)\s*(.*?)\s*$/ )
      {
      my $name = $2;
      my $opts = $3; # options/arguments, FIXME: upcase/lowcase?
  
      de_log_debug( "        isa:  [$name][$opts]" );  

      my $isa = __load_table_des_hash( $name );

      boom "isa/include error: cannot load config [$name] at [$fname:$ln]" unless $isa;

      my @opts = split /[\s,]+/, uc $opts;

      de_log_debug( "        isa:  DUMP: " . Dumper($isa) );  
      
      for my $opt ( @opts ) # FIXME: covers arg $opt
        {
        my $isa_category;
        my $isa_sect_name;
        if( $opt =~ /(([a-zA-Z_][a-zA-Z_0-9]*):)?([a-zA-Z_][a-zA-Z_0-9]*)/ )
          {
          $isa_category  = uc( $2 || $opt->{ 'DEFAULT_CATEGORY' } || '*' );
          $isa_sect_name = uc( $3 );
          }
        else
          {
          boom "isa/include error: invalid key [$opt] in [$name] at [$fname:$ln]";
          }  
        if( $category ne $isa_category )  
          {
          boom "isa/include error: cannot inherit kyes from different categories, got [$isa_category] expected [$category] key [$opt] in [$name] at [$fname:$ln]";
          }
        boom "isa/include error: non existing key [$opt] in [$name] at [$fname:$ln]" if ! exists $isa->{ $isa_category } or ! exists $isa->{ $isa_category }{ $isa_sect_name };
        $des->{ $category }{ $sect_name } ||= {};
        %{ $des->{ $category }{ $sect_name } } = ( %{ $des->{ $category }{ $sect_name } }, %{ dclone( $isa->{ $isa_category }{ $isa_sect_name } ) } );
        }
      
      next;
      }

    if( $line =~ /^([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      $key = $DES_KEY_SHORTCUTS{ $key } if exists $DES_KEY_SHORTCUTS{ $key };
      boom "unknown attribute key [$key] for table [$table] category [$category] section [$sect_name] at [$fname:$ln]" unless exists $DES_ATTRS{ $category }{ $key };

      if( $value =~ /^(['"])(.*?)\1/ )
        {
        $value = $2;
        }
      elsif( $value eq '' )
        {
        $value = 1;
        }

      de_log_debug( "            key:  [$sect_name]:[$key]=[$value]" );

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
    __merge_table_des_file( $des, $table, $file, {} );
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
  $des->{ '@' }{ '_TABLE_NAME'   } = $table;
  $des->{ '@' }{ '_FIELDS_LIST'  } = \@fields;
  $des->{ '@' }{ '_INDEXES_LIST' } = \@indexes;
  $des->{ '@' }{ 'DSN'           } = uc( $des->{ '@' }{ 'DSN' } ) || 'MAIN';

###  print STDERR "TABLE DES AFTER SELF PP [$table]:" . Dumper( $des );
  # postprocessing FIELDs ---------------------------------------------------
  
  for my $field ( @fields )
    {
    my $fld_des = $des->{ 'FIELD' }{ $field };
    my $type_des = { %TYPE_ATTRS };
    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $fld_des->{ 'TYPE' };
    my $type = shift @type;

    # "high" level types
    if( $type eq 'LINK' )
      {
      $fld_des->{ 'LINKED_TABLE' } = shift @type;
      $fld_des->{ 'LINKED_FIELD' } = shift @type;

      $type = 'INT';
      @type = qw( 32 ); # length
      }
    elsif( $type eq 'BACKLINK' )
      {
      $fld_des->{ 'BACKLINKED_TABLE' } = shift @type;
      $fld_des->{ 'BACKLINKED_KEY'   } = shift @type;

      $type = 'INT';
      @type = qw( 32 ); # length
      }
    
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
    }

  # add empty keys to fields description before locking
  for my $category ( qw( FIELD INDEX ) )
    {
    for my $key ( keys %{ $des->{ $category } })
      {
      for my $attr ( keys %{ $DES_ATTRS{ $category } } )
        {
        next if exists $des->{ $category }{ $key }{ $attr };
        $des->{ $category }{ $key }{ $attr } = undef;
        }
      }  
    }  

  print STDERR "TABLE DES POST PROCESSSED [$table]:" . Dumper( $des );

  bless $des, 'Decor::Core::Table::Description';
  dlock $des;
  #hash_lock_recursive( $des );
  
  return $des;
}

#-----------------------------------------------------------------------------

sub __load_table_description
{
  my $table = uc shift;

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: table description cache hit for [$table]" );
    return $DES_CACHE{ 'TABLE_DES' }{ $table };
    }
  elsif( $DES_CACHE_PRELOADED )  
    {
    return undef;
    }

  my $des = {};
  tie %$des, 'Tie::IxHash';

  my $rc;
  $rc = __merge_table_des_hash( $des, '_DE_UNIVERSAL' );
  # zero $rc for UNIVERSAL is ok
  $rc = __merge_table_des_hash( $des, $table );
  return undef unless $rc > 0;
  __postprocess_table_des_hash( $des, $table );

  $DES_CACHE{ 'TABLE_DES' }{ $table } = $des;
  
  return $des;
}

sub describe_table
{
  my $table = uc shift;

  my $des = __load_table_description( $table );

  if( ! $des )
    {
    my $tables_dirs = __get_tables_dirs();
    boom "cannot find/load description for table [$table] dirs [@$tables_dirs]";
    }
  
  return $des;
}

sub preload_all_table_descriptions
{
  my $tables = des_get_tables_list();

  for my $table ( @$tables )
    {
    de_log_debug( "preloading description for table [$table]" );
    describe_table( $_ );
    };

  $DES_CACHE_PRELOADED = 1;
}

sub describe_table_field
{
  my $table = shift;
  my $field = shift;
  
  my $des = describe_table( $table );
  return $des->get_field_des( $field );
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

#-----------------------------------------------------------------------------

sub des_exists
{
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
    my $des = __load_table_description( $table );
    return 1 if   $des and @_ == 1;
    return 0 if ! $des;
    }  

  # table exists, but field check is expected
  my $field = $_[1];
  return 0 unless de_check_name( $field );
  
  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table }{ $field } )
    {
    return 2 if @_ == 2;
    }
  else
    {
    return 0;
    }  
  
  # table and field exist, but attribute check is expected
  my $attr = $_[2];

  if( exists $DES_CACHE{ 'TABLE_DES' }{ $table }{ $field }{ $attr } )
    {
    return 3 if @_ == 3;
    }
  else
    {
    return 0;
    }  

  return 0; # catch-all, should be unreachable
}

### EOF ######################################################################
1;
