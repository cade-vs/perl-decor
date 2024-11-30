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
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Core::Shop;
use Decor::Shared::Utils;
use Data::Tools;
use Data::Dumper;

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
  list-users
  create-group  group_name                  <group id>
  create-user   user_name        user_pass  <user_id>
  user-pwd      user_name_or_id  user_pass
  add-groups    user_name_or_id  group1 group2...
  del-groups    user_name_or_id  group1 group2...
  del-groups    user_name_or_id  all
  user-enable   user_name_or_id
  user-disable  user_name_or_id
  ubc           table table table...
  wal-on        set table WAL/LOGGING on
  wal-off       set table WAL/LOGGING off

  user-set-active-groups  user_name_or_id  primary_group_name_or_id private_group_name_or_id
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -fd is invalid, correct is: -f -d
  * "ubc" updates backlink counters in the listed table or in all if left empty
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

de_set_log_prefix( 'decor-core-tools' );

#-----------------------------------------------------------------------------

de_init( APP_NAME => $opt_app_name );

my $cmd = lc shift @args;

if( $cmd eq 'list-users' )  
  {
  cmd_list_users( @args );
  }
elsif( $cmd eq 'create-user' )
  {
  cmd_create_user( @args );
  }
elsif( $cmd eq 'create-group' )
  {
  cmd_create_group( @args );
  }
elsif( $cmd eq 'user-pwd' )  
  {
  cmd_user_pwd( @args );
  }
elsif( $cmd eq 'user-enable' )  
  {
  cmd_user_enable_disable( 1, @args );
  }
elsif( $cmd eq 'user-disable' )  
  {
  cmd_user_enable_disable( 0, @args );
  }
elsif( $cmd eq 'add-groups' )  
  {
  add_groups( @args );
  }
elsif( $cmd eq 'del-groups' )  
  {
  del_groups( @args );
  }
elsif( $cmd eq 'user-set-active-groups' )  
  {
  user_set_active_groups( @args );
  }
elsif( $cmd eq 'ubc' )  
  {
  ubc( @args );
  }
elsif( $cmd eq 'wal-on' )  
  {
  set_wal( 1, @args );
  }
elsif( $cmd eq 'wal-off' )  
  {
  set_wal( 0, @args );
  }
else
  {
  die "unknown command [$cmd]\n";
  }  

#-----------------------------------------------------------------------------

sub cmd_create_user
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

  my $grp_rec = new Decor::Core::DB::Record;
  $grp_rec->create( 'DE_GROUPS' );
  $grp_rec->write( 
                    NAME      => $user, 
                  );
  $grp_rec->save();

  $user_rec->create( 'DE_USERS', $uid );
  
  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    NAME      => $user, 
                    PASS      => $user_pass_hex,
                    PASS_SALT => $user_salt,
                    ACTIVE    => 1,
                  );
  $user_rec->write( 'PRIMARY_GROUP' => $grp_rec->id() );
  $user_rec->write( 'PRIVATE_GROUP' => $grp_rec->id() );
  
  $user_rec->save();
  $user_rec->commit();
  
  my $usid = $user_rec->id();
  my $grid = $grp_rec->id();
  my $name = $user_rec->read( 'NAME' );
  print "info: new user [$name] created with id [$usid] and private+primary group [$grid]\n";
}

#-----------------------------------------------------------------------------

sub cmd_create_group
{
  my $grp  = shift;
  my $gid  = shift;
  
  my $grp_rec = new Decor::Core::DB::Record;

  if( $grp_rec->select_first1( 'DE_GROUPS', '.NAME = ?', { BIND => [ $grp ] } ) )
    {
    $gid = $grp_rec->id();
    print "error: group [$grp] already exists with id [$gid]\n";
    return;
    }

  $grp_rec->create( 'DE_GROUPS', $gid );
  
  $grp_rec->write( 
                    NAME      => $grp, 
                  );
  
  $grp_rec->save();
  $grp_rec->commit();
  
  my $gid = $grp_rec->id();
  print "info: new group [$grp] created with id [$gid]\n";
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

sub cmd_user_enable_disable
{
  my $state = shift;
  my $user = shift;

  my $user_rec = find_user( $user );
  
  $user_rec->write( 'ACTIVE' => $state );
  
  $user_rec->save();
  $user_rec->commit();
  
  my $ss = $state ? 'enabled' : 'disabled';
  my $usid = $user_rec->id();
  my $name = $user_rec->read( 'NAME' );
  print "info: user account [$name] with id [$usid] is now $ss\n";
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

sub find_group
{
  my $grp = shift;

  my $grp_rec = new Decor::Core::DB::Record;

  if( $grp =~ /^\d+$/ )
    {
    if( $grp <= 0 or ! $grp_rec->load( 'DE_GROUPS', $grp ) )
      {
      die "error: group id [$grp] not found\n";
      }
    }
  else
    {  
    if( $grp eq '' or ! $grp_rec->select_first1( 'DE_GROUPS', '.NAME = ?', { BIND => [ $grp ] } ) )
      {
      die "error: group [$grp] not found\n";
      }
    }  
  
  return $grp_rec;  
}

#-----------------------------------------------------------------------------

sub cmd_list_users
{
  my @args = @_;
  
  my @ids   = grep { $_ =~ /^\d+$/ } @args;
  my @names = grep { $_ =~ /\D/ } @args;

  my $bind_names = join ',', @names;
  my @where;
  my @bind;
  
  if( @ids )
    {
    my $bind_ids   = '?,' x @ids;
    chop( $bind_ids );
    push @where, "_ID IN ( $bind_ids )";
    push @bind, @ids;
    }

  if( @names )
    {
    my $bind_names   = '?,' x @names;
    chop( $bind_names );
    push @where, "NAME IN ( $bind_names )";
    push @bind, @names
    }
    
  my $where = join( ' or ', @where ) if @bind;
  
  
  my $user_rec = new Decor::Core::DB::Record;
  $user_rec->select( 'DE_USERS', $where, { BIND => \@bind, ORDER_BY => 'DESC' } );
  
  my $ufields = $user_rec->get_fields_list();
  while( $user_rec->next() )
    {
    my @u;
    push @u, { KEY => 'NAME', VALUE => $user_rec->read_formatted( 'NAME' ) };
    
    for my $field ( @$ufields )
      {
      next if $field eq 'NAME'; # already on top
      my $value = $user_rec->read_formatted( $field );
      $value = "length <".length($value).">" if $field =~ /^(PASS|PASS_SALT)$/;
      if( $field eq 'GROUPS' )
        {
        my @gg;
        my $gg = $user_rec->select_backlinked_records( 'GROUPS' );
        push @gg, $gg->read( 'GRP' ) while $gg->next();
        $value = scalar(@gg) . " => " . join ', ', sort { $a <=> $b } @gg;
        }
      push @u, { KEY => $field, VALUE => $value };

      # TODO: FIXME: enable last login sessions
      if( $field eq 'LAST_LOGIN_SESSION' )
        {
        my $ll = new Decor::Core::DB::Record;
        next unless $ll->load( 'DE_SESSIONS', $value );
        for my $fll ( @{ $ll->get_fields_list() } )
          {
          my $vll = $ll->read_formatted( $fll );
          # print "$fll -> $vll\n";
          }
        next;
        }
      }

    print format_ascii_table( \@u );
    }
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
  elsif( @_ > 0 )  
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

sub user_set_active_groups
{
  my $user = shift;
  my $pgrp  = shift; # primary group
  my $vgrp  = shift; # private group
  
  my $user_rec = find_user( $user );
  my $pgrp_rec = find_group( $pgrp  );
  my $vgrp_rec = find_group( $vgrp  );
  
  $user_rec->write( 'PRIMARY_GROUP' => $pgrp_rec->id() );
  $user_rec->write( 'PRIVATE_GROUP' => $vgrp_rec->id() );
  
  $user_rec->save();
  $user_rec->commit();

  print "ok\n";
  
}

#-----------------------------------------------------------------------------

sub ubc
{
  my @tables = @_;
  @tables = @{ des_get_tables_list() } unless @tables > 0;

  for my $t ( @tables )
    {
    my $des = describe_table( $t );
    my $fields = $des->get_fields_list();
    for my $f ( @$fields )
      {
      my $fld_des = $des->get_field_des( $f );
      next unless $fld_des->{ 'TYPE' }{ 'NAME' } eq 'BACKLINK';
      my $bt = $fld_des->{ 'BACKLINKED_TABLE' };
      my $bk = $fld_des->{ 'BACKLINKED_KEY'   };
      my $stmt = "update $t set $f = ( select count(*) from $bt where $bt.$bk = $t._id ) where $t._id > 0";

      print "$stmt\n";
      print "$t:$f ===> ";
      my $rc = io_exec_by_table( $t, $stmt ); 
      print "$rc row(s)\n";
      dsn_commit();
      }
    }

  print "done.\n";
}

#-----------------------------------------------------------------------------

sub set_wal
{
  my $log = shift() ? 'LOGGED' : 'UNLOGGED';
  my @tables = @_;
  @tables = @{ des_get_tables_list() } unless @tables > 0;

  for my $t ( @tables )
    {
    my $stmt = "alter table $t set $log";

    print "$stmt\n";
    print "$t ===> $log ===> ";
    my $rc = io_exec_by_table( $t, $stmt ); 
    print "$rc\n";
    dsn_commit();
    }

  print "done.\n";
}

#-----------------------------------------------------------------------------
