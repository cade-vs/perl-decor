#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  https://github.com/cade-vs/perl-decor
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );

use Time::HR;

use Data::Dumper;
use Storable qw( dclone );
use Data::Lock qw( dlock dunlock );
use Data::Tools 1.09;
use Config::Terse;
use LWP::UserAgent;
use Storable;
use Crypt::CBC;
use MIME::Base64;
use Data::HexDump;

use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::Log;
use Decor::Core::DB::IO;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $opt_app_name;
my $opt_verbose;

our $help_text = <<END;
usage: $0 <options> application_name config-file
options:
    -v        -- verbose output
    -d        -- debug mode, can be used multiple times to rise debug level
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
config-file format:
    beam-to    http://site/path/
    key        encryption key
    table      table name
    fields     fields list
    where      where clause
    --
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
END

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
    
  if( /^-v/ )
    {
    $opt_verbose = 1;
    next;
    }
  if( /^-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name = shift @args;

de_init( APP_NAME => $opt_app_name );

my $cfn = shift @args;
my $cfg = terse_config_load( $cfn );
 
die "no data in config file or other file error [$cfn]\n" unless $cfg;

print Dumper( $cfg );

for my $bd ( grep { $_ ne '.' and $_ ne '' } keys %$cfg )
  {
  beam_data( $bd, $cfg->{ $bd } );
  }


sub beam_data
{
  my $bd  = shift;
  my $cfg = shift;
  
  my $to     = $cfg->{ 'TO'     };
  my $table  = $cfg->{ 'TABLE'  };
  my $fields = $cfg->{ 'FIELDS' };
  my $where  = $cfg->{ 'WHERE'  };
  my $key    = $cfg->{ 'KEY'    };
  
  my $dio = new Decor::Core::DB::IO;

  my %data;

  $data{ 'TABLE'     } = $table;
  $data{ 'CTIME'     } = time();
  $data{ 'CTIME_STR' } = localtime( time() );
  $data{ 'DATA'      } = [];
  
  $dio->select( $table, $fields, $where ) or die "error in TABLE, FIELDS or WHERE in section [$bd] in config file [$cfn]\n";
  
  while( my $hr = $dio->fetch() )
    {
    push @{ $data{ 'DATA'      } }, $hr;
    }

  print Dumper( $Storable::VERSION, \%data );

  my $ua = LWP::UserAgent->new( timeout => 32 );
  my $res = $ua->post( $to, 'content-type' => 'binary/x-beam', Content => MIME::Base64::encode_base64url( encrypt_data( $key, Storable::nfreeze( \%data ) ) ) );

  print Dumper( $res );

}

sub encrypt_data
{
  my $key  = shift;
  my $data = shift;
  my $ci   = shift || 'Twofish2';

  die "invalid or empty key" unless $key =~ /\S/;

  return Crypt::CBC->new( -key => $key, -cipher => $ci )->encrypt( $data );
}

sub decrypt_data
{
  my $key  = shift;
  my $data = shift;
  my $ci   = shift || 'Twofish2';

  die "invalid or empty key" unless $key =~ /\S/;

  return Crypt::CBC->new( -key => $key, -cipher => $ci )->decrypt( $data );
}
