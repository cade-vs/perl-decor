##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Utils;
use strict;

use Data::Tools;
use Exception::Sink;

use Decor::Shared::Utils;
use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_get_core_subtype_dirs
                de_core_subtype_file_find

                );

my %SUBTYPE_DIRS_CACHE;

# TODO: handle language translations
sub de_get_core_subtype_dirs
{
  my $subtype = lc shift;
  
  return $SUBTYPE_DIRS_CACHE{ 'SUBTYPE_DIRS_AR' }{ $subtype } if exists $SUBTYPE_DIRS_CACHE{ 'SUBTYPE_DIRS_AR' }{ $subtype };

  de_check_name_boom( $subtype, "invalid dir SUBTYPE [$subtype]" );
  
  my $root         = de_root();
  my $app_dir     = de_app_dir();
  my $bundles_dirs = de_bundles_dirs();
  
  my @dirs;
  push @dirs, "$app_dir/$subtype";
  push @dirs, "$_/$subtype" for reverse @$bundles_dirs;
  push @dirs, "$root/core/$subtype";

  $SUBTYPE_DIRS_CACHE{ 'SUBTYPE_DIRS_AR' }{ $subtype } = \@dirs;

  return \@dirs;
}

sub de_core_subtype_file_find
{
  my $subtype = lc shift;
  my $ext     = lc shift;
  my $name    = lc shift;
  
  de_check_name_boom( $subtype, "invalid SUBTYPE [$subtype]"    );
  de_check_name_boom( $ext,     "invalid FILE EXTENSION [$ext]" );
  de_check_name_boom( $name,    "invalid FILE NAME [$name]"     );

  my $dirs = de_get_core_subtype_dirs( $subtype );

  my @file;

  for my $dir ( @$dirs )
    {
    my $file = "$dir/$name" . ( $ext ? ".$ext" : undef );
    next unless -e $file;
    return $file if ! wantarray();
    push @file, $file;
    }
  
  return @file if wantarray();
  return undef;
}


### EOF ######################################################################
1;
