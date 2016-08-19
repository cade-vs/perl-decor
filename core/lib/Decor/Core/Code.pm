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
use Decor::Core::Env;
use Decor::Core::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_code_file_find
                de_code_get_map

                );


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
    print "$k $v\n";
    next unless $k =~ /^on_/;
    my $code = \&{ "decor::${ctype}::${name}::$k" };
    $map{ $k } = $code;
    }

  dlock \%map;
  return \%map;
}

### EOF ######################################################################
1;
