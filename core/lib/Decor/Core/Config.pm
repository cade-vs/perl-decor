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

use Storable qw( dclone );
use Tie::IxHash;
use Data::Dumper;
use Data::Tools 1.09;
use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_config_load
                de_config_merge

                de_config_load_file
                de_config_merge_file

                );

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

  my $key_types = $opt->{ 'KEY_TYPES' } || {};

  my $order = 0;
  
  my $inf;
  open( $inf, $fname ) or return;

  print STDERR "config: open: $fname\n" if $opt->{ 'DEBUG' };  

  my $sect_name = '@'; # self :) should be more like 0
  $config->{ $sect_name } ||= {};
  my $file_mtime = file_mtime( $fname );
  if( $config->{ $sect_name }{ '_MTIME' } < $file_mtime )
    {
    # of all files merged, keep only the latest modification time
    $config->{ $sect_name }{ '_MTIME' } = $file_mtime;
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
    print STDERR "        line: [$line]\n" if $opt->{ 'DEBUG' };  

    if( $line =~ /^=([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
         $sect_name = uc $1;
      my $sect_opts =    $2; # fixme: upcase/locase?

      print STDERR "       =sect: [$sect_name]\n" if $opt->{ 'DEBUG' };  
      
      $config->{ $sect_name } ||= {};
      $config->{ $sect_name }{ 'LABEL' } ||= $sect_name;
      # FIXME: URGENT: copy only listed keys! no all
      %{ $config->{ $sect_name } } = ( %{ dclone( $config->{ '@' } ) }, %{ $config->{ $sect_name } } );
      $config->{ $sect_name }{ '_ORDER' } = $opt->{ '_ORDER' }++;
      
      if( de_debug() ) # FIXME: move to const var?
        {
        $config->{ $sect_name }{ 'DEBUG::ORIGIN' } ||= [];
        push @{ $config->{ $sect_name }{ 'DEBUG::ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^@(isa|include)\s*([a-zA-Z_0-9]+)\s*(.*?)\s*$/ )
      {
      my $name = $2;
      my $opts = $3; # options/arguments, FIXME: upcase/locase?
  
      next unless $dirs and @$dirs > 0;
      
      print STDERR "        isa:  [$name][$opts]\n" if $opt->{ 'DEBUG' };  

      my $isa = de_config_load( $name, $dirs );

      boom "isa/include error: cannot load config [$name] from (@$dirs)" unless $isa;

      my @opts = split /[\s,]+/, uc $opts;

      print STDERR "        isa:  DUMP: ".Dumper($isa)."\n" if $opt->{ 'DEBUG' };  
      
      for my $opt ( @opts )
        {
        boom "isa/include error: non existing key [$opt] in [$name]" unless exists $isa->{ $opt };
        $config->{ $opt } ||= {};
        %{ $config->{ $opt } } = ( %{ $config->{ $opt } }, %{ dclone( $isa->{ $opt } ) } );
        }
      
      next;
      }

    if( $line =~ /^([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      $value = 1 if $value eq '';

      print STDERR "            key:  [$sect_name]:[$key]=[$value]\n" if $opt->{ 'DEBUG' };  

      if( $key_types->{ $key } eq '@' )
        {
        $config->{ $sect_name }{ $key } ||= [];
        push @{ $config->{ $sect_name }{ $key } }, $value;
        }
      else
        {  
        $config->{ $sect_name }{ $key } = $value;
        }
      
      next;
      }


    }
  close( $inf );
  
  return 1;
}

### EOF ######################################################################
1;
