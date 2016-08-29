##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Subs;
use strict;
use Exception::Sink;
use Data::Tools;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Core::Subs::Env;
use Decor::Core::Utils;
use Decor::Core::Profile;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                subs_process_xt_message

                );

##############################################################################


##############################################################################

my %DISPATCH_MAP = (
                     'GLOBAL' => {
                                   'CAPS'     => \&sub_caps,
                                   'RESET'    => \&sub_reset,
                                   'END'      => \&sub_end,
                                   'SEED'     => \&sub_seed,
                                 },
                     'MAIN'   => {
                                   'BEGIN'    => \&sub_begin,
                                   'PREPARE'  => \&sub_begin_prepare,
                                 },
                     'USER'   => {
                                   'DESCRIBE' => \&sub_describe,
                                   'MENU'     => \&sub_menu,
                                   'SELECT'   => \&sub_select,
                                   'FETCH'    => \&sub_fetch,
                                   'FINISH'   => \&sub_finish,
                                   'INSERT'   => \&sub_insert,
                                   'UPDATE'   => \&sub_update,
                                   'DELETE'   => \&sub_delete,
                                   'COMMIT'   => \&sub_commit,
                                   'ROLLBACK' => \&sub_rollback,
                                   'LOGOUT'   => \&sub_logout,
                                 },
                   );

my %MAP_SHORTCUTS = (
                    'A'   => 'CAPS',
                    'B'   => 'BEGIN',
                    'C'   => 'COMMIT',
                    'D'   => 'DESCRIBE',
                    'E'   => 'END',
                    'F'   => 'FETCH',
                    'H'   => 'FINISH',
                    'I'   => 'INSERT',
                    'M'   => 'MENU',
                    'P'   => 'PREPARE',
                    'R'   => 'ROLLBACK',
                    'S'   => 'SELECT',
                    'T'   => 'DELETE',
                    'U'   => 'UPDATE',
                    );

my $DISPATCH_MAP = 'MAIN';

sub subs_set_dispatch_map
{
  my $map = uc shift;
  
  boom "unknown DISPATCH MAP [$map]" unless exists $DISPATCH_MAP{ $map };
  $DISPATCH_MAP = $map;
}

sub subs_reset_dispatch_map
{
  $DISPATCH_MAP = 'MAIN';
}

sub subs_process_xt_message
{
  my $mi = shift;
  my $mo = shift;
  
  my $xt = uc $mi->{ 'XT' };

  $xt = $MAP_SHORTCUTS{ $xt } if exists $MAP_SHORTCUTS{ $xt };

  my $mapc = $DISPATCH_MAP{ $DISPATCH_MAP }; # current 
  my $mapg = $DISPATCH_MAP{ 'GLOBAL' };      # global
  boom "unknown or forbidden DMAP:XTYPE [$DISPATCH_MAP:$xt] current DMAP is [$DISPATCH_MAP]" unless exists $mapc->{ $xt } or exists $mapg->{ $xt };

  my $handle = $mapc->{ $xt } || $mapg->{ $xt };

  my $res = $handle->( $mi, $mo );
}

##############################################################################

sub sub_caps
{
  my $mi = shift;
  my $mo = shift;

  $mo->{ 'VER'   } = de_version();
  $mo->{ 'UTIME' } = time();
  
  $mo->{ 'XS'    } = 'OK';
  return 1;
};

sub sub_reset
{
  my $mi = shift;
  my $mo = shift;

  subs_reset_dispatch_map();
  subs_reset_current_all();
  
  $mo->{ 'XS'    } = 'OK';
  return 1;
};

#--- LOGIN/LOGOUT ------------------------------------------------------------

my $BEGIN_SALT;

sub sub_begin_prepare
{
  my $mi = shift;
  my $mo = shift;

  $BEGIN_SALT = create_random_id( 128 );
  $mo->{ 'LOGIN_SALT'  } = $BEGIN_SALT;
  
  my $user = $mi->{ 'USER' };
  if( $user )
    {
    my $user_rec = __sub_find_user( $user );
    $mo->{ 'USER_SALT'  } = $user_rec->read( 'PASS_SALT' );
    }
  
  $mo->{ 'XS'    } = 'OK';
  return 1;
};

sub sub_begin
{
  my $mi = shift;
  my $mo = shift;

  my $user     = $mi->{ 'USER'     };
  my $pass     = $mi->{ 'PASS'     };
  my $user_sid = $mi->{ 'USER_SID' };
  my $remote   = $mi->{ 'REMOTE'   };
  
  if( $user and $pass )
    {
    # user/pass login
    __sub_begin_with_user_pass( $user, $pass, $remote );
    }
  elsif( $user_sid )
    {
    # session continue
    # TODO: param/ip/addr
    __sub_begin_with_session_continue( $user_sid, $remote );
    }
  else
    {
    boom "invalid XT=BEGIN parameters";
    }  

  my $user = subs_get_current_user();
  my $sess = subs_get_current_session();
  
  my $sess_sid = $sess->read( 'SID' );
  
  my $profile = new Decor::Core::Profile;
  $profile->add_groups_from_user( $user );
  
  # TODO: decide on group IDs
  $profile->add_groups( 999 ); # all
  $profile->remove_groups( 900, 901 ); # nobody

  subs_lock_current_profile( $profile );

  $mo->{ 'SID'   } = $sess_sid;
  # TODO: expire time, further advise
  $mo->{ 'XS'    } = 'OK';
};

sub __sub_begin_with_user_pass
{
  my $user   = shift;
  my $pass   = shift;
  my $remote = shift;
  boom "login seed is empty, call XT=BEGIN_PREPARE first" unless $BEGIN_SALT;
  boom "invalid remote string" unless de_check_user_login_name( $remote );
  my $begin_salt = $BEGIN_SALT;
  $BEGIN_SALT = undef;
  subs_lock_current_user( __sub_find_and_check_user_pass( $user, $pass, $begin_salt ) );

  my $user = subs_get_current_user();

  # TODO: allow/deny root login
  die "E_LOGIN: User not active" unless $user->read( 'ACTIVE' ) > 0;

  my $session_rec = new Decor::Core::DB::Record;
  
  $session_rec->create( 'DE_SESSIONS' );
  $session_rec->write(
                     'ACTIVE' => 1,
                     'USR'    => $user->id(),
                     'CTIME'  => time(),
                     'ETIME'  => 0,
                     'ATIME'  => time(),
                     'XTIME'  => time() + 15*60, # FIXME: get from config!
                     'REMOTE' => $remote,
                     );

  my $ss_time = time();
  while(4)
    {
    my $sid = create_random_id( 128 );
    $session_rec->write( 'SID' => $sid );
    my $sp_name = 'BEGIN_NEW_SESSION';
    $session_rec->savepoint( $sp_name );
    eval
      {
      $session_rec->save();
      };
    if( $@ )  
      {
      $session_rec->rollback_to_savepoint( $sp_name );
      de_log_debug( "debug: error: session create hit existing session, retry" );
      }
    else
      {
      de_log( "status: new session created for user [$user] sid [$sid]" );
      last;
      }  
    if( time() - $ss_time > 5 )
      {
      boom "E_SESSION: cannot create session for user [$user] hit existing timeout";
      }
    }

  subs_lock_current_session( $session_rec );

  return 1;
};

sub __sub_begin_with_session_continue
{
  my $user_sid = shift;
  my $remote   = shift;

  my $session_rec = __sub_find_session( $user_sid, $remote );
  
  if( $session_rec->read( 'XTIME' ) < time() )
    {
    $session_rec->write(
                       'ACTIVE' => 0,
                       'ETIME'  => time(),
                       'ATIME'  => time(),
                       );
    $session_rec->save();
    
    sub_reset( $mi, $mo );
    return 1;
    }
  
  return 1;
};

sub __sub_find_user
{
  my $user_name = shift;

  boom "E_LOGIN: Invalid user login name [$user_name]" unless de_check_user_login_name(  $user_name );

  my $user_rec = new Decor::Core::DB::Record;

  $user_rec->select( 'DE_USERS', 'NAME = ?', { BIND => [ $user_name ] } );
  if( $user_rec->next() )
    {
    $user_rec->finish();
    return $user_rec;
    }
  boom "E_LOGIN: User not found [$user_name]";
  return undef; # never reached
};

sub __sub_find_and_check_user_pass
{
  my $user = shift;
  my $pass = shift; # expected to be whirlpool de_password_salt_hash()
  my $salt = shift;

  my $user_rec = __sub_find_user( $user );
  
  boom "E_LOGIN: User not active [$user]"         unless $user_rec->read( 'ACTIVE' );
  boom "E_LOGIN: Invalid user [$user] password"   unless de_check_user_pass_digest( $pass );
  
  my $user_pass = $user_rec->read( 'PASS' );
  # TODO: use configurable digests
  my $user_pass_hex = de_password_salt_hash( $user_pass, $salt ); 
  boom "E_LOGIN: Wrong user [$user] password"   unless $pass eq $user_pass_hex;
  return $user_rec;
};

sub __sub_find_session
{
  my $session_sid = shift;
  my $remote      = shift;

  boom "invalid session sid"   unless de_check_name( $session_sid );
  boom "invalid remote string" unless de_check_user_login_name( $remote );

  my $session_rec = new Decor::Core::DB::Record;

  $session_rec->select( 'DE_SESSIONS', 'SID = ? AND REMOTE = ? AND ACTIVE = ?', { BIND => [ $session_sid, $remote, 1 ] } );
  if( $session_rec->next() )
    {
    $session_rec->finish();
    return $session_rec;
    }
  boom "E_SESSION: Session not found [$session_sid] from remote [$remote]";
  return undef; # never reached
};

sub sub_end
{
  my $mi = shift;
  my $mo = shift;

  my $user_sid = $mi->{ 'USER_SID' };
  my $remote   = $mi->{ 'REMOTE'   };

  my $session_rec = __sub_find_session( $user_sid, $remote );
  
  $session_rec->write(
                     'ACTIVE' => 0,
                     'ETIME'  => time(),
                     'ATIME'  => time(),
                     );
  $session_rec->save();

  sub_reset( $mi, $mo );
  
  $mo->{ 'XS'    } = 'OK';
};

#--- DESCRIBE/MENU -----------------------------------------------------------

sub sub_describe
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_menu
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- SELECT/FETCH/FINISH -----------------------------------------------------

sub sub_select
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_fetch
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_finish
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- INSERT/UPDATE/DELETE ----------------------------------------------------

sub sub_insert
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_update
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_delete
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- CONTROLS/COMMIT/ROLLBACK/ETC. -------------------------------------------

sub sub_commit
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_rollback
{
  my $mi = shift;
  my $mo = shift;
  
};


### EOF ######################################################################
1;
