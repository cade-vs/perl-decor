##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Config;
use strict;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_config_load
                de_config_merge

                de_config_load_file
                de_config_merge_file

                );

use Storable qw( dclone );
use Tie::IxHash;
use Data::Dumper;
use Data::Tools 1.09;
use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Log;


# FIXME catch nesting loops

##############################################################################

sub de_config_merge
{
  my $config =    shift; # config hash ref
  my $name   = lc shift; # file name (config name) to look for
  my $dirs   =    shift; # array reference with dir names
  my $opt    = shift || {};
  
  de_check_name( $name  ) or boom "invalid NAME: [$name]";
  
  my @files = __de_resolve_config_files( $name, $dirs );

  return undef unless @files > 0;
  
  for my $file ( @files )
    {
    de_config_merge_file( $config, $file, $dirs, $opt );
    }
  
  return 1;
}

sub de_config_load
{
  my $name  = lc shift;
  my $dirs  =    shift; # array reference
  my $opt   = shift || {};

  my $config = {};
  tie %$config, 'Tie::IxHash';
  
  my $res = de_config_merge( $config, $name, $dirs, $opt );
  
  return $res ? $config : undef;
}

sub de_config_load_file
{
  my $fname = shift;
  my $dirs  = shift || []; # array reference
  my $opt   = shift || {};

  my $config = {};
  de_config_merge_file( $config, $fname, [], $opt );
  
  return $config;
}

sub __de_resolve_config_files
{
  my $name  = lc shift;
  my $dirs  =    shift; # array reference

  return () unless $dirs and @$dirs > 0;

  my @files;
  
  push @files, glob_tree( "$_/$name.def" ) for @$dirs;

  return @files;
}

sub de_config_merge_file
{
  my $config = shift; # config hash ref
  my $fname  = shift;
  my $dirs   = shift; # array reference
  my $opt    = shift || {};

  my $key_types  = $opt->{ 'KEY_TYPES'  } || {};
  my $categories = $opt->{ 'CATEGORIES' };

  my $order = 0;
  
  my $inf;
  open( $inf, $fname ) or boom "cannot open config file [$fname]";

  de_log_debug( "config: open: $fname" );  

  my $sect_name = '@'; # self :) should be more like 0
  my $category  = '@';
  $config->{ $category }{ $sect_name } ||= {};
  my $file_mtime = file_mtime( $fname );
  if( $config->{ $category }{ $sect_name }{ '_MTIME' } < $file_mtime )
    {
    # of all files merged, keep only the latest modification time
    $config->{ $category }{ $sect_name }{ '_MTIME' } = $file_mtime;
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
         $category  = uc( $2 || $opt->{ 'DEFAULT_CATEGORY' } || '*' );    
         $sect_name = uc( $3 );
      my $sect_opts =     $4; # fixme: upcase/locase?

      boom "invalid category [$category] at [$fname:$ln]" if $categories and ! exists $categories->{ $category };

      de_log_debug( "       =sect: [$category:$sect_name]" );  
      
      $config->{ $category }{ $sect_name } ||= {};
      $config->{ $category }{ $sect_name }{ 'LABEL' } ||= $sect_name;
      # FIXME: URGENT: copy only listed keys! no all
###      %{ $config->{ $category }{ $sect_name } } = ( %{ dclone( $config->{ '@' }{ '@' } ) }, %{ $config->{ $category }{ $sect_name } } );
      $config->{ $category }{ $sect_name }{ '_ORDER' } = $opt->{ '_ORDER' }++;
      
      if( de_debug() ) # FIXME: move to const var?
        {
        $config->{ $category }{ $sect_name }{ 'DEBUG::ORIGIN' } ||= [];
        push @{ $config->{ $category }{ $sect_name }{ 'DEBUG::ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^@(isa|include)\s*([a-zA-Z_0-9]+)\s*(.*?)\s*$/ )
      {
      my $name = $2;
      my $opts = $3; # options/arguments, FIXME: upcase/lowcase?
  
      next unless $dirs and @$dirs > 0;
      
      de_log_debug( "        isa:  [$name][$opts]" );  

      my $isa = de_config_load( $name, $dirs );

      boom "isa/include error: cannot load config [$name] from (@$dirs) at [$fname:$ln]" unless $isa;

      my @opts = split /[\s,]+/, uc $opts;

      de_log_debug( "        isa:  DUMP: " . Dumper($isa) );  
      
      for my $opt ( @opts )
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
        $config->{ $category }{ $sect_name } ||= {};
        %{ $config->{ $category }{ $sect_name } } = ( %{ $config->{ $category }{ $sect_name } }, %{ dclone( $isa->{ $isa_category }{ $isa_sect_name } ) } );
        }
      
      next;
      }

    if( $line =~ /^([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      if( $value =~ /^(['"])(.*?)\1/ )
        {
        $value = $2;
        }
      elsif( $value eq '' )
        {
        $value = 1;
        }

      de_log_debug( "            key:  [$sect_name]:[$key]=[$value]" );

      if( $key_types->{ $key } eq '@' )
        {
        $config->{ $category }{ $sect_name }{ $key } ||= [];
        push @{ $config->{ $category }{ $sect_name }{ $key } }, $value;
        }
      else
        {  
        $config->{ $category }{ $sect_name }{ $key } = $value;
        }
      
      next;
      }


    }
  close( $inf );
  
  return 1;
}

### EOF ######################################################################
1;
