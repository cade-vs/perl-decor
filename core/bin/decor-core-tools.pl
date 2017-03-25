#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
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


my $opt_app_name;

our $help_text = <<END;
usage: $0 <options> application_name command args
options:
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
commands:    
  add-user   user_name        user_pass  <user_id>
  user-pwd   user_name_or_id  user_pass
  add-groups user_name_or_id  group1 group2...
  del-groups user_name_or_id  group1 group2...
  del-groups user_name_or_id  all
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

if( $cmd eq 'add-user' )
  {
  cmd_user_add( @args );
  }
elsif( $cmd eq 'user-pwd' )  
  {
  cmd_user_pwd( @args );
  }
elsif( $cmd eq 'add-groups' )  
  {
  add_groups( @args );
  }
elsif( $cmd eq 'del-groups' )  
  {
  del_groups( @args );
  }
else
  {
  die "unknown command [$cmd]\n";
  }  

#-----------------------------------------------------------------------------

sub cmd_user_add
{
  my $user = shift;
  my $pass = shift;
  my $uid  = shift;
  
  $pass = ask_pass() if $pass eq 'ask' or ! $pass;
  
  my $user_rec = new Decor::Core::DB::Record;

  if( $user_rec->select_first1( 'DE_USERS', '.NAME = ?', { BIND => [ $user ] } ) )
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
  
  my $usid = $user_rec->id();
  my $name = $user_rec->read( 'NAME' );
  print "info: new user [$name] created with id [$usid]\n";
}

#-----------------------------------------------------------------------------

sub cmd_user_pwd
{
  my $user = shift;
  my $pass = shift;

  $pass = ask_pass() if $pass eq 'ask' or ! $pass;
  
  my $user_rec = find_user( $user );

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

  my $usid = $user_rec->id();
  my $name = $user_rec->read( 'NAME' );
  print "info: password changed for existing user [$name] with id [$usid]\n";
}


#-----------------------------------------------------------------------------

sub find_user
{
  my $user = shift;

  my $user_rec = new Decor::Core::DB::Record;

  if( $user =~ /^\d+$/ )
    {
    if( $user <= 0 or ! $user_rec->load( 'DE_USERS', $user ) )
      {
      die "error: user id [$user] not found\n";
      }
    }
  else
    {  
    if( $user eq '' or ! $user_rec->select_first1( 'DE_USERS', '.NAME = ?', { BIND => [ $user ] } ) )
      {
      die "error: user [$user] not found\n";
      }
    }  
  
  return $user_rec;  
}

#-----------------------------------------------------------------------------

sub ask_pass
{
  print "\n";
  ReadMode( 'noecho' );
  print "Enter new password: ";
  my $pwd1 = ReadLine(0);
  print "\n";
  print "Enter the new password again: ";
  my $pwd2 = ReadLine(0);
  print "\n";
  ReadMode( 0 );
  chomp( $pwd1 );
  chomp( $pwd2 );

  die "error: password(s) empty or trivial\n" unless $pwd1 and $pwd2;
  die "error: passwords do not match\n" unless $pwd1 eq $pwd2;
  # TODO: password strength?
    
  return $pwd1;  
}

#-----------------------------------------------------------------------------

sub add_groups
{
  my $user = shift;

  my $user_rec = find_user( $user );
  
  my $dio = new Decor::Core::DB::IO;

  my $user_id = $user_rec->id();
  for my $group ( @_ )
    {
    if( $dio->read_first1_hashref( 'DE_USER_GROUP_MAP', 'USR = ? AND GRP = ?', { BIND => [ $user_id, $group ] } ) )
      {
      print "user [$user] id [$user_id] already has group [$group]\n";
      }
    else
      {
      my $rc = $dio->insert( 'DE_USER_GROUP_MAP', { USR => $user_id, GRP => $group } );
      print "user [$user] id [$user_id] added group [$group] result record id: $rc\n";
      }  
    }
  $user_rec->commit();
}

sub del_groups
{
  my $user = shift;
  
  my $user_rec = find_user( $user );

  my $dio = new Decor::Core::DB::IO;

  my $user_id = $user_rec->id();
  
  if( @_ == 1 and lc( $_[0] ) eq 'all' )
    {
    my $rc = $dio->delete( 'DE_USER_GROUP_MAP', 'USR = ?', { BIND => [ $user_id ] } );
    print "user [$user] id [$user_id] removed all groups: $rc\n";
    }
  elsif( @_ > 1 )  
    {
    for my $group ( @_ )
      {
      my $rc = $dio->delete( 'DE_USER_GROUP_MAP', 'USR = ? AND GRP = ?', { BIND => [ $user_id, $group ] } );
      my $rcs = $rc > 0 ? 'OK' : 'NOT_FOUND/ERROR';
      print "user [$user] id [$user_id] removed group [$group] result: $rcs\n";
      }
    }
  else
    {
    die "expected list of groups or 'all'\n";
    }  
  $user_rec->commit();
}

#-----------------------------------------------------------------------------
