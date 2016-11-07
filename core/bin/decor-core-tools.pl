#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Shared::Utils;
use Data::Tools;


my $opt_app_name;

our $help_text = <<END;
usage: $0 <options> application_name command args
options:
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
commands:    
  add-user  user_name  user_pass  <user_id>
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -fd is invalid, correct is: -f -d
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

my $cmd = lc shift @args;

cmd_user_add( @args ) if $cmd eq 'add-user';

#-----------------------------------------------------------------------------

sub cmd_user_add
{
  my $user = shift;
  my $pass = shift;
  my $uid  = shift;
  
  
  my $user_rec = new Decor::Core::DB::Record;

  if( $user_rec->select_first1( 'DE_USERS', 'NAME = ?', { BIND => [ $user ] } ) )
    {
    $uid = $user_rec->id();
    print "error: user [$user] already exists with id [$uid]\n";
    return;
    }

  $user_rec->create( 'DE_USERS', $uid );
  
  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    NAME      => $user, 
                    PASS      => $user_pass_hex,
                    PASS_SALT => $user_salt,
                    ACTIVE    => 1,
                  );
  
  $user_rec->save();
  $user_rec->commit();
}

sub cmd_user_pwd
{
  my $user = shift;
  my $pass = shift;
  
  
  my $user_rec = new Decor::Core::DB::Record;

  if( ! $user_rec->select_first1( 'DE_USERS', 'NAME = ?', { BIND => [ $user ] } ) )
    {
    print "error: user [$user] not found\n";
    return;
    }

  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    NAME      => $user, 
                    PASS      => $user_pass_hex,
                    PASS_SALT => $user_salt,
                    ACTIVE    => 1,
                  );
  
  $user_rec->save();
  $user_rec->commit();
}
