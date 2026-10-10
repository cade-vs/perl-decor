#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Term::ReadKey;
use Decor::Core::Boot;
use Decor::Core::Debug;
use Decor::Core::Log;
use Decor::Core::Loader::Table;
use Decor::Shared::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Shared::Utils;
use Data::Tools;
use Exception::Sink;


my $opt_app_name;

our $help_text = <<END;
usage: $0 <options> application_name table <record_id>
options:
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
END

if( @ARGV == 0 )
  {
  print $help_text;
  exit;
  }

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /^-r(r)?$/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^-d$/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name = lc shift @args;

if( $opt_app_name =~ /^[A-Z_0-9]+$/i )
  {
  print "info: application name in use [$opt_app_name]\n";
  }
else
  {
  print "error: invalid application name [$opt_app_name]\n";
  exit 1;
  }  

#-----------------------------------------------------------------------------

de_boot( APP_NAME => $opt_app_name );

my $table = uc shift @args;
my $id    =    shift @args;

# FIXME: missing table name is reported by the DB layer as "invalid TABLE name []", should be checked here with usage

if( $id )
  {
  check_rec( $table, $id );
  }
else
  {
  my $io = new Decor::Core::DB::IO;
  $io->select( $table, '_ID', '._ID > 0', { ORDER_BY => '_ID' } );
  while( my $hr = $io->fetch() )
    {
    check_rec( $table, $hr->{ '_ID' } );
    print "\n";
    print "-" x 72;
    print "\n";
    }
  }  


sub check_rec
{
  my $table = shift;
  my $id    = shift;
  my $level = shift;
  my $seen  = shift || {};

  $level++;
  my $pad = '    ' x $level;
  
  if( $seen->{ "$table:$id" }++ )
    {
    print "$pad table [$table] record [$id] SEEN OK\n";
    return;
    }

  my $io = new Decor::Core::DB::IO;
  
  my $data = $io->read_first1_by_id_hashref( $table, $id, { MANUAL => 1 } );
  die "$pad error: cannot load table [$table] record [$id]+\n\n" unless $data;

  print "$pad table [$table] record [$id] OK\n";

  my $tdes = load_table( $table );

  my $fields = des_fields_list( $tdes );

  for my $field ( @$fields )
    {
    my $fdes = des_field_des( $tdes, $field );
    next unless des_is_linked( $fdes );
    print "$pad [$field]\n";
    my ( $ltable, $lfield ) = des_link_details( $fdes );
    check_rec( $ltable, $data->{ $field }, $level, { %$seen } );
    }
}
