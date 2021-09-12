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
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
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
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^-d/ )
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

de_init( APP_NAME => $opt_app_name );

my $table = uc shift @args;
my $id    =    shift @args;

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

  my $tdes = describe_table( $table );

  my $fields = $tdes->get_fields_list();

  for my $field ( @$fields )
    {
    my $fdes = $tdes->get_field_des( $field );
    next unless $fdes->is_linked();
    print "$pad [$field]\n";
    my ( $ltable, $lfield ) = $fdes->link_details();
    check_rec( $ltable, $data->{ $field }, $level, { %$seen } );
    }
}
