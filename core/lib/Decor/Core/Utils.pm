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
use Decor::Core::Describe;
use Decor::Core::Shop;
use Decor::Core::Subs::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_get_core_subtype_dirs
                de_core_subtype_file_find

                de_add_alog_rec
                de_add_alog_rec_if_des

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

sub de_add_alog_rec
{
  my $oper = shift;
  my $rec  = shift;

  my $data = ref_freeze( { $rec->read_hash( '*' ) } );

  my $log_rec = record_create( 'DE_ALOG' );
  $log_rec->write(
                  USR   => subs_get_current_user()->read( 'DATA' ),
                  SESS  => subs_get_current_session_id(),
                  TAB   => $rec->table(),
                  OID   => $rec->id(),
                  OPER  => $oper,
                  CTIME => time(),
                  DATA  => $data,
                );
              
  $log_rec->save();            
  
  return 1;
}

sub de_add_alog_rec_if_des
{
  my $oper = shift;
  my $rec  = shift;
  
  return 0 unless describe_table( $rec->table() )->get_table_des()->{ 'ALOG' };
  
  return de_add_alog_rec( $oper, $rec );
}

### EOF ######################################################################
1;
