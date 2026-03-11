#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core RSA tools
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade" <cade@noxrun.com>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Term::ReadKey;
use Decor::Core::Env;
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Core::Shop;
use Decor::Shared::Utils;
use Data::Tools;
use Data::Dumper;
use Crypt::PK::RSA;

$|++;

my $opt_app_name;
my $opt_all_yes;

our $help_text = <<END;
usage: $0 <options> application_name command args
options:
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    -y        -- assume "yes" answer to all questions :)
    --        -- end of options
commands:    
  keygen

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
  if( /^-y/ )
    {
    $opt_all_yes = 1;
    print "option: assuming 'yes' to all questions \n";
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

de_set_log_prefix( 'decor-core-rsa' );

#-----------------------------------------------------------------------------

de_init( APP_NAME => $opt_app_name );

my $cmd = lc shift @args;

if( $cmd eq 'keygen' )  
  {
  keygen( @args );
  }
else
  {
  die "unknown command [$cmd]\n";
  }  



sub keygen
{
  my $name = shift;
  die "keygen needs name parameter: $0 keygen newkey" unless $name;

  my $keydir = de_app_dir() . '/keys';
  dir_path_ensure( $keydir ) or die "cannot access or created dest dir [$keydir]\n";

  my $pem_pvt_fn = "$keydir/$name-pvt.pem";
  my $pem_pub_fn = "$keydir/$name-pub.pem";
  
  die "error: $pem_pvt_fn already exists\n" if -e $pem_pvt_fn;
  die "error: $pem_pub_fn already exists\n" if -e $pem_pub_fn;
  
  my $pk = Crypt::PK::RSA->new;
  $pk->generate_key( 512, 65537 );  # 256 bytes = 2048 bits, 512 = 4096 bits

  my $pvt_pem = $pk->export_key_pem( 'private' );
  my $pub_pem = $pk->export_key_pem( 'public'  );
  
  file_save( $pem_pvt_fn, $pvt_pem ) or die "cannot save PRIVATE key [$pem_pvt_fn]\n";
  file_save( $pem_pub_fn, $pub_pem ) or die "cannot save PUBLIC  key [$pem_pub_fn]\n";

  print "done. keys saved: $keydir/$name-*.key\n";
}
