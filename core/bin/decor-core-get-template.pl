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
usage: $0 <options> app_name table1 table2...
summary:
    $0 will install DEF and PM template files for given table names
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
my $root = de_root();

for( @args )
  {
  install_template( $_, 'def' );
  install_template( $_, 'pm'  );
  }

sub install_template
{
  my $table = lc shift;
  my $ext   = lc shift;
  
  my $if = "$root/core/templates/table.$ext";
  my $of = "$table.$ext";

  if( ! -r $if )
    {
    print "cannot read template [$if], skipped!\n";
    return;
    }

  if( -e $of )
    {
    print "target already exists [$of], skipped!\n";
    return;
    }

  my $data = file_text_load( $if ) or return error( "empty file or read error for file [$if]\n" );
  $data =~ s/\[--TABLE--\]/$table/g;
  file_text_save( $of, $data ) or return error( "cannot save file [$of]\n" );

  print "file [$of] saved ok.\n";
  
  return 1;
}


sub error
{
  print STDERR @_;
  return undef;
}
