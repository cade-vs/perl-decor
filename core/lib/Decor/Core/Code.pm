##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Code;
use strict;

use Data::Lock qw( dlock dunlock );

use Exception::Sink;

use Decor::Shared::Utils;
use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_code_reset_map

                de_code_file_find
                de_code_get_map

                );

# TODO: preload_all_code() ? 

my %CODE_CACHE;

sub __get_code_dirs
{
  my $ctype = lc shift;
  
  return $CODE_CACHE{ 'CODE_DIRS_AR' }{ $ctype } if exists $CODE_CACHE{ 'CODE_DIRS_AR' }{ $ctype };

  de_check_name_boom( $ctype, "invalid CODE TYPE [$ctype]" );
  
  my $root         = de_root();
  my $app_path     = de_app_path();
  my $modules_dirs = de_modules_dirs();
  
  my @dirs;
  push @dirs, "$app_path/$ctype";
  push @dirs, "$_/$ctype" for reverse @$modules_dirs;
  push @dirs, "$root/core/$ctype";

  $CODE_CACHE{ 'CODE_DIRS_AR' }{ $ctype } = \@dirs;

  return \@dirs;
}

sub de_code_file_find
{
  my $ctype = lc shift;
  my $name  = lc shift;
  
  de_check_name_boom( $ctype, "invalid CODE TYPE [$ctype]" );
  de_check_name_boom( $name,  "invalid CODE NAME [$name]" );

  my $dirs = __get_code_dirs( $ctype );

  for my $dir ( @$dirs )
    {
    my $file = "$dir/$name.pm";
    return $file if -e $file;
    }
  
  return undef;
}

sub de_code_get_map
{
  my $ctype = lc shift;
  my $name  = lc shift;
  
  return $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name } if exists $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name };
  
  my $file = de_code_file_find( $ctype, $name );
  return undef unless $file;

  eval
    {
    require $file;
    };
  if( $@ )  
    {
    boom "error loading code file [$file] reason: $@";
    }

  boom "missing decor:: namespace for DECOR user code"  unless exists $main::{ 'decor::' };
  boom "missing decor::${ctype}:: namespace for DECOR user code" unless exists $main::{ 'decor::' }{ $ctype . '::' };
  boom "missing decor::${ctype}::${name}:: namespace for DECOR user code" unless exists $main::{ 'decor::' }{ $ctype . '::' }{ $name . '::' };
  
  my %map;
  
  while( my ( $k, $v ) = each %{ $main::{ 'decor::' }{ $ctype . '::' }{ $name . '::' } } )
    {
    #print "$k $v\n";
    next unless $k =~ /^on_/;
    my $code = \&{ "decor::${ctype}::${name}::$k" };
    $k = uc $k;
    boom "duplicate TRIGGER [$k] found in code type [$ctype] name [$name] file [$file]" if exists $map{ $k };
    $map{ $k } = $code;
    }

  dlock \%map;
  $CODE_CACHE{ 'CODE_MAPS' }{ $ctype }{ $name } = \%map;
  return \%map;
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

### EOF ######################################################################
1;
