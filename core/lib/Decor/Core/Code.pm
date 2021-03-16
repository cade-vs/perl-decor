##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Code;
use strict;

use Data::Dumper;
use Data::Lock qw( dlock dunlock );

use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Shared::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_code_reset_map

                de_code_file_find
                de_code_get_map
                de_code_exists
                de_code_reset_map
                
                de_code_exec

                );

# TODO: preload_all_code() ? 

my %CODE_CACHE;

sub de_code_get_map
{
  my $ctype = lc shift;
  my $name  = lc shift;
  
  return $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name } if exists $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name };
  
  my $file = de_core_subtype_file_find( $ctype, 'pm', $name );
  return undef unless $file;


  eval
    {
    require $file;
    };
  if( $@ )  
    {
    boom "error loading code file [$file] reason: $@";
    }

  boom "missing decor:: namespace for DECOR user code"                    unless exists $main::{ 'decor::' };
  boom "missing decor::${ctype}:: namespace for DECOR user code"          unless exists $main::{ 'decor::' }{ $ctype . '::' };
  boom "missing decor::${ctype}::${name}:: namespace for DECOR user code" unless exists $main::{ 'decor::' }{ $ctype . '::' }{ $name . '::' };
  
  my %map;
  while( my ( $k, $v ) = each %{ $main::{ 'decor::' }{ $ctype . '::' }{ $name . '::' } } )
    {
    #print "$k $v\n";
    next unless $k =~ /^on_/i;
    boom "found TRIGGER [$k] with invalid name for code type [$ctype] name [$name] file [$file]" unless $k =~ /^on_[a-z0-9][a-z_0-9]+$/;
    my $code = \&{ "decor::${ctype}::${name}::$k" };
    $k = uc $k;
    boom "duplicate TRIGGER [$k] found in code type [$ctype] name [$name] file [$file]" if exists $map{ $k };
    $map{ $k } = $code;
    }

  dlock \%map;
  $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name } = \%map;
  return \%map;
}

sub de_code_exists
{
  my $ctype   = shift;
  my $name    = shift;
  my $trigger = uc shift;

  de_check_name_boom( $name,  "invalid CODE TRIGGER name [$trigger]" );

  $trigger = "ON_$trigger" unless $trigger =~ /^ON_/;

  my $map = de_code_get_map( $ctype, $name );

#print Dumper( 'de-code-exists'x10, $ctype, $name, $trigger, $map );
  
  return undef unless $map;
  return undef unless exists $map->{ $trigger };
  return 1;
}

sub de_code_reset_map
{
  my $ctype = lc shift;
  my $name  = lc shift;

  if( $ctype eq '*' )
    {
    delete $CODE_CACHE{ 'CODE_MAPS' };
    return 1;
    }
  
  delete $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name } if $ctype and $name;
  delete $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }          if $ctype;
  
  return 1;
}

sub de_code_exec
{
  my $ctype   = shift;
  my $name    = shift;
  my $trigger = uc shift;
  
  my $map = de_code_get_map( $ctype, $name );

#print Dumper( 'de-code-exec'x10, $ctype, $name, $trigger, $map );
  
  boom "requested exec for TRIGGER [$trigger] but it does not exist for code type [$ctype] name [$name]" unless de_code_exists( $ctype, $name, $trigger );

  $trigger = "ON_$trigger" unless $trigger =~ /^ON_/;

  return $map->{ $trigger }->( @_ );
}

### EOF ######################################################################
1;
