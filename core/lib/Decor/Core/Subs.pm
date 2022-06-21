##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Subs;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;
use Data::Tools::Socket;
use Data::Structure::Util qw( unbless );

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Core::Subs::Env;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::Menu;
use Decor::Core::Code;
use Decor::Core::DSN;

use Clone qw( clone );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                subs_process_xt_message

                );

##############################################################################

my %DISPATCH_MAP = (
                     'GLOBAL' => {
                                   'CAPS'     => \&sub_caps,
                                   'RESET'    => \&sub_reset,
                                   'END'      => \&sub_end,
                                 },
                     'MAIN'   => {
                                   'BEGIN'    => \&sub_begin,
                                 },
                     'USER'   => {
                                   'LOGIN'    => \&sub_login,
                                   'PREPARE'  => \&sub_login_prepare,

                                   'SEED'     => \&sub_seed,
                                   'DESCRIBE' => \&sub_describe,
                                   'MENU'     => \&sub_menu,
                                   'SELECT'   => \&sub_select,
                                   'FETCH'    => \&sub_fetch,
                                   'FINISH'   => \&sub_finish,
                                   'NEXTID'   => \&sub_get_next_id,
                                   'INSERT'   => \&sub_insert,
                                   'UPDATE'   => \&sub_update,
                                   'DELETE'   => \&sub_delete,
                                   'RECALC'   => \&sub_recalc,
                                   'LOGOUT'   => \&sub_logout,
                                   'DO'       => \&sub_do,
                                   'ACCESS'   => \&sub_access,
                                   'FSAVE'    => \&sub_file_save,
                                   'FLOAD'    => \&sub_file_load,
                                   'PCHECK'   => \&sub_check_user_password,
                                   'WORK'     => \&sub_begin_work,
                                   'COMMIT'   => \&sub_commit,
                                   'ROLLBACK' => \&sub_rollback,
                                 },
                                 
                   );

my %MAP_SHORTCUTS = (
                    'A'   => 'CAPS',
                    'B'   => 'BEGIN',
                    'C'   => 'COMMIT',
                    'D'   => 'DESCRIBE',
                    'E'   => 'END',
                    'F'   => 'FETCH',
                    'FS'  => 'FSAVE',
                    'FL'  => 'FLOAD',
                    'H'   => 'FINISH',
                    'I'   => 'INSERT',
                    'L'   => 'RECALC',
                    'LI'  => 'LOGIN',
                    'LO'  => 'LOGOUT',
                    'M'   => 'MENU',
                    'N'   => 'NEXTID',
                    'O'   => 'DO',
                    'P'   => 'PREPARE',
                    'PC'  => 'PCHECK',
                    'R'   => 'ROLLBACK',
                    'S'   => 'SELECT',
                    'T'   => 'DELETE',
                    'U'   => 'UPDATE',
                    'W'   => 'WORK',
                    'X'   => 'ACCESS',
                    );

my $DISPATCH_MAP = 'MAIN';

my %SELECT_WHERE_OPERATORS = (
                    '='    => '=',
                    '=='   => '=',
                    '<'    => '<',
                    '<='   => '<=',
                    '>'    => '>',
                    '>='   => '>=',
                    '<>'   => '<>',
                    'LIKE' => 'LIKE',
                    'IN'   => 'IN',
                    'eq'   => '=',
                    'lt'   => '<',
                    'le'   => '<=',
                    'gt'   => '>',
                    'ge'   => '>=',
                    'ne'   => '<>',

                    'GREP' => 'GREP',
                    );


my %SELECT_MAP;
my $SELECT_MAP_COUNTER;
my $SELECT_MAP_COUNT;

my $PREPARE_LOGIN_SESSION_SALT;

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
  my $socket = shift;
  
  my $xt = uc $mi->{ 'XT' };

  $xt = $MAP_SHORTCUTS{ $xt } if exists $MAP_SHORTCUTS{ $xt };

  my $mapc = $DISPATCH_MAP{ $DISPATCH_MAP }; # current
  my $mapg = $DISPATCH_MAP{ 'GLOBAL'      }; # global
  boom "unknown or forbidden DMAP:XTYPE [$DISPATCH_MAP:$xt] current DMAP is [$DISPATCH_MAP]" unless exists $mapc->{ $xt } or exists $mapg->{ $xt };

  my $handle = $mapc->{ $xt } || $mapg->{ $xt };

  de_log_debug( "debug: processing XTYPE [$xt] xt code handle [$handle]" );

  my $res = $handle->( $mi, $mo, $socket );
}

##############################################################################

sub sub_caps
{
  my $mi = shift;
  my $mo = shift;

  my $app_name = $mi->{ 'APP_NAME' };
  if( $app_name )
    {
    boom "invalid APP_NAME [$app_name]" unless de_check_name( $app_name );
    de_init( APP_NAME => $app_name );
    }

  $mo->{ 'VER'   } = de_version();
  $mo->{ 'UTIME' } = time();

  $mo->{ 'XS'    } = 'OK';
  return 1;
};

sub __sub_reset_state
{
  subs_reset_dispatch_map();
  subs_reset_current_all();
  
  %SELECT_MAP         = ();
  $SELECT_MAP_COUNTER = 0;
  $SELECT_MAP_COUNT   = 0;
  
  $PREPARE_LOGIN_SESSION_SALT = undef;
  
  return 1;
}

sub sub_reset
{
  my $mi = shift;
  my $mo = shift;

  __sub_reset_state();

  $mo->{ 'XS'    } = 'OK';
  return 1;
};

#--- NEW BEGIN/LOGIN/LOGOUT/END-----------------------------------------------

sub __session_update_times
{
  my $session_rec = shift;
  my $force       = shift;

  my $atime = $session_rec->read( 'ATIME' );
  
  # update access & expire time but not less than a minute away
  return 0 unless $force or time() - $atime > 60;

  my $xtime = $session_rec->read( 'USR' ) == 909 ?
              de_app_cfg( 'SESSION_ANON_EXPIRE_TIME', 24*60*60 ) # 24 hours for anonimous sessions
              :
              de_app_cfg( 'SESSION_USER_EXPIRE_TIME',    10*60 ) # 10 min for logged-in user sessions
              ;

  $session_rec->write(
                       'ATIME' => time(),
                       'XTIME' => time() + $xtime,
                     );
  
  return 1;
}

sub __session_check_xtime
{
  my $session_rec = shift;
  
  #print STDERR Dumper( '*' x 100, $session_rec, time() );

  # TODO: use variable-length or fixed-length sessions
  return 1 if $session_rec->read( 'XTIME' ) > time();

  # session expired
  $session_rec->write(
                       'ACTIVE' => 0,
                       'ETIME'  => time(),
                     );
  $session_rec->save();

  # TODO: FIXME: IF: set last login session logout time in $user?

  __sub_reset_state();
    
  die "E_SESSION_EXPIRED: user session expired";
}

sub __create_new_anon_session
{
  my $remote = shift;
  
  my $time_now = time(); # to keep the same time for all data here

  my $session_rec = new Decor::Core::DB::Record;

  $session_rec->create( 'DE_SESSIONS' );
  $session_rec->write(
                     'ACTIVE' => 1,
                     'USR'    => 909, # ANON
                     'CTIME'  => $time_now,
                     'ETIME'  => 0,
                     'ATIME'  => $time_now,
                     'XTIME'  => $time_now,
                     'REMOTE' => $remote,
                     );

  __session_update_times( $session_rec, 1 );

  my $ss_time = time();
  while(4)
    {
    my $sid = create_random_id( 137 );
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
      de_log_debug( "debug: error: session create hit existing session, retry [$@]" );
      }
    else
      {
      de_log( "status: new ANON session created [$sid]" );
      last;
      }
    if( time() - $ss_time > 5 )
      {
      die "E_SESSION: cannot create ANON session due timeout";
      }
    }

  return $session_rec;
}

sub __sub_find_session
{
  my $session_sid = shift;
  my $remote      = shift;

  boom "invalid session sid"   unless de_check_name( $session_sid );
  boom "invalid remote string" unless de_check_user_login_name( $remote );

  my $session_rec = new Decor::Core::DB::Record;

  $session_rec->select( 'DE_SESSIONS', 'SID = ? AND REMOTE = ? AND ACTIVE = ?', { BIND => [ $session_sid, $remote, 1 ], LOCK => 1 } );
  if( $session_rec->next() )
    {
    $session_rec->finish();
    return $session_rec;
    }
  
  die "E_SESSION: Session not found [$session_sid] from remote [$remote]";
  return undef; # never reached
};

sub __setup_user_profile
{
  my $user_rec = shift;

  my $profile = new Decor::Core::Profile;
  
  if( $user_rec->id() == 909 )
    {
    # anonymous connection
    $profile->add_groups( 909 ); 
    $profile->remove_groups( 999, 900, 901 ); # everyone, nobody, noone

    # primary group
    $profile->set_primary_group( 909 );
    }
  else
    {
    # reguler user (including root)
    $profile->add_groups_from_user( $user_rec );

    # common groups setup
    $profile->add_groups( 999 ); # all/everybody
    $profile->remove_groups( 900, 901, 909 ); # nobody, noone, anonymous

    # primary group
    $profile->set_primary_group( $user_rec->get_primary_group() );

    # enable root access if user is root (id==1)
    $profile->enable_root_access() if $user_rec->id() == 1;
    }  
    
  return $profile;  
}

sub __sub_find_user
{
  my $user_name = shift;

  die "E_LOGIN: Invalid user login name [$user_name]" unless de_check_user_login_name(  $user_name );

  my $user_rec = new Decor::Core::DB::Record;

  $user_rec->select( 'DE_USERS', 'NAME = ?', { BIND => [ $user_name ], LOCK => 1 } );
  if( $user_rec->next() )
    {
    $user_rec->finish();
    return $user_rec;
    }
  die "E_LOGIN: User not found [$user_name]";
  return undef; # never reached
};

sub __sub_find_and_check_user_pass
{
  my $user = shift;
  my $pass = shift; # expected to be whirlpool de_password_salt_hash()
  my $salt = shift;

  my $user_rec = __sub_find_user( $user );

  die "E_LOGIN: User [$user] not active"              unless $user_rec->is_active();
  die "E_LOGIN: Invalid password for user [$user] "   unless de_check_user_pass_digest( $pass );

  my $user_pass = $user_rec->read( 'PASS' );
  # TODO: use configurable digests
  my $user_pass_hex = de_password_salt_hash( $user_pass, $salt );
  die "E_LOGIN: Wrong password for user [$user]" unless $pass eq $user_pass_hex;
  return $user_rec;
};

sub sub_begin
{
  my $mi = shift;
  my $mo = shift;

  my $user_sid = $mi->{ 'USER_SID' };
  my $remote   = $mi->{ 'REMOTE'   };

  my $session_rec;
  
  if( $user_sid eq 'CREATE' )
    {
    $session_rec = __create_new_anon_session( $remote );
    }
  elsif( $user_sid )  
    {
    $session_rec = __sub_find_session( $user_sid, $remote );
    }

  # first check expire time
  __session_check_xtime(  $session_rec );
  # then update the new expire and access times
  __session_update_times( $session_rec );

  $session_rec->save();

  my $user_rec = $session_rec->get_link_record( 'USR' );
  boom "E_INTERNAL: cannot load USER for session [$user_sid] and remote [$remote]" unless $user_rec;
  
  my $profile = __setup_user_profile( $user_rec );

  subs_lock_current_profile( $profile );
  subs_lock_current_user( $user_rec );
  subs_lock_current_session( $session_rec );

  subs_set_dispatch_map( 'USER' );
  
  $mo->{ 'SID'   } = $session_rec->read( 'SID' );
  $mo->{ 'UGS'   } = $profile->get_groups_hr(); # user groups (UGS)
  $mo->{ 'UN'    } = $user_rec->read( 'NAME' );
  $mo->{ 'XTIME' } = $session_rec->read( 'XTIME' );
  $mo->{ 'XS'    } = 'OK';
}

sub sub_login_prepare
{
  my $mi = shift;
  my $mo = shift;

  my $user     = $mi->{ 'USER' };
  my $user_rec = $user ? __sub_find_user( $user ) : undef;
  
  my $user_salt = $user_rec ? $user_rec->read( 'PASS_SALT' ) : undef;
     $user_salt = create_random_id( 128 ) unless de_check_name( $user_salt );
  
  $PREPARE_LOGIN_SESSION_SALT = create_random_id( 128 );

  $mo->{ 'LOGIN_SALT' } = $PREPARE_LOGIN_SESSION_SALT;
  $mo->{ 'USER_SALT'  } = $user_salt;
  $mo->{ 'XS'         } = 'OK';

  return 1;
}

sub sub_login
{
  my $mi = shift;
  my $mo = shift;

  my $user     = $mi->{ 'USER'     };
  my $pass     = $mi->{ 'PASS'     };
  my $remote   = $mi->{ 'REMOTE'   };

  die "E_LOGIN: ANONYMOUS login is forbidden" if $user =~ /^(ANON|ANONYMOUS)$/;

  my $session_salt = $PREPARE_LOGIN_SESSION_SALT;
  $PREPARE_LOGIN_SESSION_SALT = undef;

  die "E_INTERNAL: missing session SALT, call XT=PREPARE first" unless de_check_name( $session_salt );
  die "E_INTERNAL: invalid remote string" unless de_check_user_login_name( $remote );
  
  my $user_rec = __sub_find_and_check_user_pass( $user, $pass, $session_salt );

  # TODO: allow/deny root login
  die "E_LOGIN: User not active" unless $user_rec->read( 'ACTIVE' ) > 0;

  my $session_rec = subs_get_current_session();
     $session_rec->write(
                          '_OWNER' => $user_rec->read( 'PRIVATE_GROUP' ),
                          'USR'    => $user_rec->id(),
                          'REMOTE' => $remote,
                        );
  __session_update_times( $session_rec, 1 );
  $session_rec->save();

  my $profile = __setup_user_profile( $user_rec );

  my $pass_xtime = $user_rec->read( 'PASS_XTIME' );
  if( $pass_xtime > 0 and $pass_xtime < time() )
    {
    # password expired
    $profile->set_groups( 908 );
    }

  subs_reset_current_all();
  subs_lock_current_profile( $profile );
  subs_lock_current_user( $user_rec );
  subs_lock_current_session( $session_rec );

  $mo->{ 'UGS'   } = $profile->get_groups_hr(); # user groups (UGS)
  $mo->{ 'UN'    } = $user_rec->read( 'NAME' );
  $mo->{ 'XTIME' } = $session_rec->read( 'XTIME' );
  $mo->{ 'XS'    } = 'OK';

  return 1;
}

sub sub_logout
{
  my $mi = shift;
  my $mo = shift;

  my $user_rec    = subs_get_current_user();
  my $session_rec = subs_get_current_session();

  $session_rec->write(
                     'ACTIVE' => 0,
                     'ETIME'  => time(),
                     'ATIME'  => time(),
                     );
  $session_rec->save();

  $user_rec->write(
                    'LAST_LOGOUT_TIME'    => time(),
                  );
  $user_rec->save();

  __sub_reset_state();

  $mo->{ 'XS'    } = 'OK';
};


sub sub_end
{
  my $mi = shift;
  my $mo = shift;

  __sub_reset_state();

  $mo->{ 'XS'    } = 'OK';
}

#--- ********** OLD *********** LOGIN/LOGOUT ---------------------------------

=for comment old login

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
  else
    {
    $mo->{ 'USER_SALT'  } = create_random_id( 128 );
    }  

  $mo->{ 'XS'    } = 'OK';
  return 1;
};

# i.e. either login or continue session
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
    boom "E_ACCESS: invalid XT=BEGIN parameters, missing USER/PASS or USER_SID and disabled ANON access" unless de_app_cfg( 'ALLOW_ANON', 0 );
    # TEST: ANON connection
    my $profile = new Decor::Core::Profile;
    $profile->add_groups( 909 ); # anonymous
    $profile->remove_groups( 999, 900, 901 ); # ANON is not everyone nor nobody
    $profile->set_primary_group( 0 );
    subs_lock_current_profile( $profile );
    subs_set_dispatch_map( 'USER' );
    
    $mo->{ 'UGS'   } = { 909 => 1 }; # user groups
    # TODO: expire time, further advise
    $mo->{ 'XTIME' } = -1; # ANON sessions are without limit
    $mo->{ 'XS'    } = 'OK';
    $mo->{ 'SID'   } = 1;
    return;
    }

  my $user = subs_get_current_user();
  my $sess = subs_get_current_session();

  my $sess_sid = $sess->read( 'SID' );

  my $profile = new Decor::Core::Profile;
  $profile->add_groups_from_user( $user );

  # common groups setup
  $profile->add_groups( 999 ); # all/everybody
  $profile->remove_groups( 900, 901 ); # nobody

  # primary group
  $profile->set_primary_group( $user->get_primary_group() );

  # enable root access if user is root (id==1)
  $profile->enable_root_access() if $user->id() == 1;

  subs_lock_current_profile( $profile );

  my $atime = $sess->read( 'ATIME' );
  if( time() - $atime > 60 )
    {
    # update access time but not less than a minute away
    $sess->write(
                  'ATIME' => time(),
                  'XTIME' => time() + de_app_cfg( 'SESSION_EXPIRE_TIME', 15*60 ), # 15 minutes default
                );
    $sess->save();
    # TODO: use variable-length or fixed-length sessions
    }

  subs_set_dispatch_map( 'USER' );

  $mo->{ 'SID'   } = $sess_sid;
  $mo->{ 'UGS'   } = { map { $_ => 1 } $profile->get_groups() }; # user groups
  # TODO: expire time, further advise
  $mo->{ 'XTIME' } = $sess->read( 'XTIME' );
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

  my $time_now = time(); # to keep the same time for all data here

  my $session_rec = new Decor::Core::DB::Record;

  $session_rec->create( 'DE_SESSIONS' );
  $session_rec->write(
                     'ACTIVE' => 1,
                     'USR'    => $user->id(),
                     'CTIME'  => $time_now,
                     'ETIME'  => 0,
                     'ATIME'  => $time_now,
                     'XTIME' => time() + de_app_cfg( 'SESSION_EXPIRE_TIME', 15*60 ), # 15 minutes default
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
      de_log_debug( "debug: error: session create hit existing session, retry [$@]" );
      }
    else
      {
      de_log( "status: new session created for user [$user] sid [$sid]" );
      last;
      }
    if( time() - $ss_time > 5 )
      {
      die "E_SESSION: cannot create session for user [$user] hit existing timeout";
      }
    }

  my $session_id = $session_rec->id();
  $user->write(
               'LAST_LOGIN_SESSION' => $session_id,
               'LAST_LOGIN_TIME'    => $time_now,
              );
  $user->save();

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
                       );
    $session_rec->save();

    __sub_reset_state();
    die "E_SESSION_EXPIRED: user session expired";
    return 1;
    }

  my $user_id = $session_rec->read( 'USR' );
  my $user_rec = new Decor::Core::DB::Record;
  $user_rec->load( 'DE_USERS', $user_id ) or boom "E_INTERNAL: cannot load USER with id [$user_id] from requested session [$user_sid] and remote [$remote]";

  subs_lock_current_user( $user_rec );
  subs_lock_current_session( $session_rec );

  return 1;
};

=cut

#--- CHECK USER PASSWORD -----------------------------------------------------

sub sub_check_user_password
{
  my $mi = shift;
  my $mo = shift;

  my $user     = $mi->{ 'USER'     };
  my $pass     = $mi->{ 'PASS'     };

  my $session_salt = $PREPARE_LOGIN_SESSION_SALT;
  $PREPARE_LOGIN_SESSION_SALT = undef;

  die "E_INTERNAL: missing session SALT, call XT=PREPARE first" unless de_check_name( $session_salt );
  die "E_PASSWORD: Invalid user [$user] or password"            unless de_check_user_pass_digest( $pass );

  my $user_rec  = subs_get_current_user();
  my $user_pass = $user_rec->read( 'PASS' );

  die "E_LOGIN: Invalid user [$user] password"   unless de_check_user_pass_digest( $pass );

  my $user_pass = $user_rec->read( 'PASS' );
  # TODO: use configurable digests
  my $user_pass_hex = de_password_salt_hash( $user_pass, $session_salt );
  die "E_PASSWORD: Wrong user [$user] password"   unless $pass eq $user_pass_hex;

  $mo->{ 'XS'    } = 'OK';
}

#--- DESCRIBE/MENU -----------------------------------------------------------

sub __replace_grant_deny
{
  my $profile = shift;
  my $hrn     = shift;
  my $hrd     = shift;

  if( $profile->has_root_access() )
    {
    $hrn->{ 'GRANT' } = { ALL => 1 };
    $hrn->{ 'DENY'  } = {};
    delete $hrn->{ 'WEB.HIDDEN' };
    return 1;
    }

  for my $grant_deny ( qw( GRANT DENY ) )
    {
    if( ! $hrd->{ $grant_deny } )
      {
      $hrn->{ $grant_deny } = {};
      next;
      }
#    while( my ( $k, $v ) = each %{ $hrd->{ $grant_deny } } )
    for my $op ( keys %{ $hrd->{ $grant_deny } } )
      {
# my $res = $profile->__check_access_tree( $op, $hrd->{ $grant_deny } );
# print STDERR "=====(@_)======+++++ [$res] <- $op, $grant_deny, " . Dumper( $hrd );
      $hrn->{ $grant_deny }{ $op } = $profile->__check_access_tree( $op, $hrd->{ $grant_deny } );
      }
    }

  for my $oper ( keys %{ $hrn->{ 'DENY' } } )
    {
    next unless $hrn->{ 'DENY' }{ $oper };
    delete $hrn->{ 'GRANT' }{ $oper };
    }

  if( $profile->check_access( 966 ) )
    {
    for( qw( READ CROSS ACCESS ) )
      {
      delete $hrn->{ 'DENY' }{ $_ };
      $hrn->{ 'GRANT' }{ $_ } = 966;
      }
    }
  if( $profile->check_access( 967 ) )
    {
    for( qw( INSERT UPDATE DELETE EXECUTE ) )
      {
      delete $hrn->{ 'GRANT' }{ $_ };
      $hrn->{ 'DENY' }{ $_ } = 967;
      }
    }

  return 1;
};

sub sub_describe
{
  my $mi = shift;
  my $mo = shift;

  my $table = $mi->{ 'TABLE' };

  boom "invalid TABLE name [$table]"   unless de_check_name( $table );

  my $profile = subs_get_current_profile();

  my $des = describe_table( $table );

  my $new = clone( { %$des } );

# print STDERR Dumper( '-'x100, $des, $new, ref($new) );

  __replace_grant_deny( $profile, $new->{ '@' }, $des->{ '@' } );
  delete $new->{ 'INDEX'  };
  delete $new->{ 'FILTER' };

  for my $cat ( qw( FIELD DO ) )
    {
    for my $field ( @{ $new->{ '@' }{ "_${cat}S_LIST" } } )
      {
      my $hrd = $des->{ $cat }{ $field };
      my $hrn = $new->{ $cat }{ $field };
      unbless $hrn;
      #dunlock $hr;
      #dunlock $hr->{ 'DENY'  };
      __replace_grant_deny( $profile, $hrn, $hrd, $table, $field );
      delete $hrn->{ 'DEBUG::ORIGIN' };
      }
    }  
# print STDERR Dumper( '='x100, $new );

  $mo->{ 'DES'   } = $new;
  $mo->{ 'XS'    } = 'OK';
};

sub sub_menu
{
  my $mi = shift;
  my $mo = shift;

  my $menu_name = uc $mi->{ 'MENU' };

  boom "invalid MENU name [$menu_name]"   unless de_check_name( $menu_name );

  my $profile = subs_get_current_profile();

  my $menu = de_menu_get( $menu_name );
  
  if( ( $profile->has_root_access() or $profile->check_access( 966 ) ) and $menu_name eq '_DE_ALL_TABLES' )
    {
    my $tables = des_get_tables_list();

    my $o = 1;
    for my $table ( sort @$tables )
      {
      $menu->{ $table }{ 'TYPE'   } = 'GRID';
      $menu->{ $table }{ 'TABLE'  } = $table;
      $menu->{ $table }{ 'GRANT'  }{ 'ACCESS' } = 1;
      $menu->{ $table }{ '_ORDER' } = $o++;
      };
    }

  my $new = clone( { %$menu } );

  for my $item ( @{ $new->{ '@' }{ '_ITEMS_LIST' } } )
    {
    my $hrm = $menu->{ $item };
    my $hrn =  $new->{ $item };
    __replace_grant_deny( $profile, $hrn, $hrm );

    delete $hrn->{ 'DEBUG::ORIGIN' };
    }

  $mo->{ 'MENU'  } = $new;
  $mo->{ 'XS'    } = 'OK';
};

#--- SELECT/FETCH/FINISH -----------------------------------------------------

sub __filter_to_where
{
  my $filter = shift;

  my @where;
  my @bind;
  while( my ( $f, $v ) = each %$filter )
    {
    $f = uc $f;
    boom "invalid FILTER FIELD [$f]"  unless $f =~ /^[A-Z_0-9\.]+$/o;

    my $vref = ref( $v );
    $v = [ $v ] if $vref eq 'HASH';
    $vref = ref( $v );

    if( $vref eq 'ARRAY' )
      {
      for my $ff ( @$v )
        {
        my $op  = uc $ff->{ 'OP'    };
        my $val =    $ff->{ 'VALUE' };
        boom "invalid OPERATOR [$op]" unless exists $SELECT_WHERE_OPERATORS{ $op };
        my $op = $SELECT_WHERE_OPERATORS{ $op };

        if( $op eq 'IN' )
          {
          $val = [ $val ] if ref( $val ) eq '';
          my $vc = @$val;
          my @inph = ( '?' ) x $vc; # IN place holders
          my $inph = join ',', @inph;

          push @where, ".$f IN ( $inph )";
          push @bind,  @$val;
          }
        elsif( $op eq 'GREP' )
          {
          push @where, "UPPER(.$f) LIKE UPPER(?)";
          push @bind,  "%$val%";
          }
        else
          {
          push @where, ".$f $op ?";
          push @bind,  $val;
          }
        }
      }
    elsif( $vref eq '' )
      {
      push @where, ".$f = ?";
      push @bind,  $v;
      }
    else
      {
      boom "invalid FILTER VALUE [$v]";
      }

    # TODO: more complex filter rules
    }

  return ( \@where, \@bind );
}

sub sub_select
{
  my $mi = shift;
  my $mo = shift;

  my $table    = uc $mi->{ 'TABLE'  };
  my $fields   = uc $mi->{ 'FIELDS' };
  my $limit    =    $mi->{ 'LIMIT'  };
  my $offset   =    $mi->{ 'OFFSET' };
  my $filter   =    $mi->{ 'FILTER' } || {};
  my $order_by = uc $mi->{ 'ORDER_BY' };
  my $group_by = uc $mi->{ 'GROUP_BY' };
  my $distinct =    $mi->{ 'DISTINCT' } ? 1 : 0;
  my $filter_name   = uc $mi->{ 'FILTER_NAME' };
  my $filter_bind   = uc $mi->{ 'FILTER_BIND' };
  my $filter_method = uc $mi->{ 'FILTER_METHOD' };

  # FIXME: TODO: Subs/MessageCheck TABLE ID FIELDS LIMIT OFFSET FILTER validate_hash()
  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid FIELDS list [$fields]"  unless $fields   =~ /^([A-Z_0-9\.\,]+|COUNT\(\*\)|\*)$/o; # FIXME: more aggregate funcs
  boom "invalid ORDER BY [$order_by]"   unless $order_by =~ /^([A-Z_0-9\.\, ]*)$/o;
  boom "invalid GROUP BY [$group_by]"   unless $group_by =~ /^([A-Z_0-9\.\, ]*)$/o;
  boom "invalid LIMIT [$limit]"         unless $limit    =~ /^[0-9]*$/o;
  boom "invalid OFFSET [$offset]"       unless $offset   =~ /^[0-9]*$/o;
  boom "invalid FILTER [$filter]"       unless ref( $filter ) eq 'HASH';
  boom "invalid FILTER_NAME name [$filter_name]"  unless $filter_name eq '' or de_check_name( $filter_name );
  boom "invalid FILTER_METHOD name [$filter_method]"  unless $filter_method eq '' or de_check_name( $filter_method );

  # TODO: check TABLE READ ACCESS

  my @where;
  my @bind;
  my ( $where, $bind ) = __filter_to_where( $filter );

  if( des_exists_category( 'FILTER', $table, 'DEFAULT_SELECT' ) )
    {
    my $tdes = describe_table( $table );
    my $filter_name_sql = $tdes->{ 'FILTER' }{ 'DEFAULT_SELECT' }{ 'SQL_WHERE' };
    push @where, $filter_name_sql if $filter_name_sql;
    }
  
  if( $filter_name )
    {
    if( des_exists_category( 'FILTER', $table, $filter_name ) )
      {
      my $tdes = describe_table( $table );
      my $filter_name_sql = $tdes->{ 'FILTER' }{ $filter_name }{ 'SQL_WHERE' };
      if( $filter_name_sql )
        {
        push @where, $filter_name_sql;
        push @bind,  split( /;/, $filter_bind ) if $filter_bind ne '';
        }
      }
    else
      {
      boom "unknown FILTER_NAME name [$filter_name] for table [$table]";
      }  
    }

  my $where_clause = join ' AND ', map { "( $_ )" } ( @$where, @where );
  my $where_bind   = [ @$bind, @bind ];
  
  my $profile = subs_get_current_profile();

  my $select_handle;
  # $select_handle = create_random_id( 64 ) while $SELECT_MAP{ $select_handle };
  $SELECT_MAP_COUNTER++;
  $SELECT_MAP_COUNT++;
  $select_handle = $SELECT_MAP_COUNTER;
  my $dbio = new Decor::Core::DB::IO;
  $SELECT_MAP{ $select_handle }{ 'IO' } = $dbio;
  $SELECT_MAP{ $select_handle }{ 'TN' } = $table;
  $SELECT_MAP{ $select_handle }{ 'FM' } = $filter_method;
  $dbio->set_profile_locked( $profile );
  $dbio->taint_mode_enable_all();

  my $res = $dbio->select( $table, $fields, $where_clause, { BIND => $where_bind, LIMIT => $limit, OFFSET => $offset, ORDER_BY => $order_by, GROUP_BY => $group_by, DISTINCT => $distinct } );

  $mo->{ 'SELECT_HANDLE' } = $select_handle;
  $mo->{ 'XS'            } = 'OK';
};


sub sub_fetch
{
  my $mi = shift;
  my $mo = shift;

  my $select_handle = $mi->{ 'SELECT_HANDLE' };
  boom "invalid SELECT_HANDLE [$select_handle]" unless exists $SELECT_MAP{ $select_handle };
  my $dbio  = $SELECT_MAP{ $select_handle }{ 'IO' };
  my $table = $SELECT_MAP{ $select_handle }{ 'TN' };
  my $fmeth = $SELECT_MAP{ $select_handle }{ 'FM' };

  my $hr = $dbio->fetch();
  if( ! $hr )
    {
    $mo->{ 'EOD'  } = 'YES'; # end of data
    $mo->{ 'XS'   } = 'OK';
    }

  if( de_code_exists( 'tables', $table, 'FETCH' ) )
    {
    de_code_exec( 'tables', $table, 'FETCH', $hr );
    }

  if( $hr and $fmeth and de_code_exists( 'tables', $table, "FILTER_METHOD_$fmeth" ) )
    {
    my $res = de_code_exec( 'tables', $table, "FILTER_METHOD_$fmeth", $hr );
    if( ! $res )
      {
      $mo->{ 'XA'   } = 'A_NEXT'; # advice
      $mo->{ 'XS'   } = 'OK';
      return;
      }
    }

  $mo->{ 'DATA' } = $hr;
  $mo->{ 'XS'   } = 'OK';
};


sub sub_finish
{
  my $mi = shift;
  my $mo = shift;

  my $select_handle = $mi->{ 'SELECT_HANDLE' };
  boom "invalid SELECT_HANDLE [$select_handle]" unless exists $SELECT_MAP{ $select_handle };
  my $dbio = $SELECT_MAP{ $select_handle }{ 'IO' };

  $dbio->finish();
  delete $SELECT_MAP{ $select_handle };
  $SELECT_MAP_COUNT--;
  if( $SELECT_MAP_COUNT <= 0 )
    {
    %SELECT_MAP         = ();
    $SELECT_MAP_COUNT   = 0;
    $SELECT_MAP_COUNTER = 0;
    }

  $mo->{ 'XS' } = 'OK';
};

#--- INSERT/UPDATE/DELETE ----------------------------------------------------

sub __sub_attach_edit_cache_sid_to_rec
{
  my $mi  = shift;
  my $rec = shift;

  return unless exists $mi->{ 'EDIT_SID' } and $mi->{ 'EDIT_SID' };
  my $esid = $mi->{ 'EDIT_SID' };

  my $sess = subs_get_current_session();
  my $sess_sid = $sess->read( 'SID' );
  
  $rec->__edit_cache_set_key( $sess_sid . '.' . $esid );
}

sub sub_get_next_id
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );

  my $dbio = new Decor::Core::DB::IO;
  my $new_id = $dbio->get_next_table_id( $table );

  my $user = subs_get_current_user();
  my $sess = subs_get_current_session();

  my $user_id = $user->id();
  my $sess_id = $sess->id();

  my $rec = new Decor::Core::DB::Record;

  $rec->create( 'DE_RESERVED_IDS' );
  $rec->write(
               'USR'            => $user_id,
               'SESS'           => $sess_id,
               'RESERVED_TABLE' => $table,
               'RESERVED_ID'    => $new_id,
               'CTIME'          => time(),
               'ACTIVE'         => 1,
             );
  $rec->save();

  $mo->{ 'RESERVED_ID' } = $new_id;
  $mo->{ 'XS' } = 'OK';
}

sub sub_insert
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $data   =    $mi->{ 'DATA'   };
  my $id     =    $mi->{ 'ID'     };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid DATA [$data]"           unless ref( $data ) eq 'HASH';
  boom "invalid ID [$id]"               if $id ne '' and ! de_check_id( $id );

  my $profile = subs_get_current_profile();
  boom "E_ACCESS: user group 967 has global write restriction" if ! $profile->has_root_access() and $profile->check_access( 967 ); # FIXME: move to common
  boom "E_ACCESS: access denied oper [INSERT] for table [$table]" unless $profile->check_access_table( 'INSERT', $table );

  $id ||= $data->{ '_ID' };
  delete $data->{ '_ID' }; # it will be filled on record creation

  if( $id > 0 )
    {
    # TODO: check reserved IDs with common func! the same code in record::write
    my $user = subs_get_current_user();
    my $sess = subs_get_current_session();

    my $user_id = $user->id();
    my $sess_id = $sess->id();

    my $res_rec = new Decor::Core::DB::Record;

    boom "E_ACCESS: invalid RESERVED_ID [$id] for table [$table] user [$user_id] session [$sess_id]"
        unless $res_rec->select_first1( 'DE_RESERVED_IDS', 'USR = ? AND SESS = ? AND RESERVED_TABLE = ? AND RESERVED_ID = ? AND ACTIVE = ?', { BIND => [ $user_id, $sess_id, $table, $id, 1 ], LOCK => 1 } );

    $res_rec->write(
                    'ETIME'       => time(),
                    'ACTIVE'      => 0,
                   );
    $res_rec->save();
    }
  else
    {
    my $dbio = new Decor::Core::DB::IO;
    $id = $dbio->get_next_table_id( $table );
    }


  my $rec = new Decor::Core::DB::Record;

  $rec->set_profile_locked( $profile );

  $rec->taint_mode_enable_all();

  $rec->create( $table, $id );
  $rec->write( %$data );

  $rec->taint_mode_disable_all();
  __sub_attach_edit_cache_sid_to_rec( $mi, $rec );
  $rec->__client_io_enable();
  $rec->method( 'INSERT' );
  $rec->edit_cache_save();

  $rec->save();

  # extra processing, attach, etc.
  my $lt_table  = uc $mi->{ 'LINK_TO_TABLE'  };
  my $lt_field  = uc $mi->{ 'LINK_TO_FIELD'  };
  my $lt_id     =    $mi->{ 'LINK_TO_ID'     };

#print STDERR "+++++++++++++++++++++++++++++++ LINK_TO table:field:id == $lt_table:$lt_field:$lt_id\n";

  if( $lt_table and $lt_field and $lt_id )
    {
    # this is a shortcut, to fall inside the same transaction
    my $rec_id = $rec->id();
    my $ui = { TABLE => $lt_table, ID => $lt_id, DATA => { $lt_field => $rec->id() } };
    my $uo = {};
    sub_update( $ui, $uo );
    boom "invalid XS received from sub_update [$lt_table:$lt_id:$lt_field=$rec_id] while linking new insert data into [$table:$rec_id]" unless $uo->{ 'XS' } eq 'OK';
    }

  $rec->inject_return_file_into_mo( $mo );

  $mo->{ 'NEW_ID' } = $rec->id();
  $mo->{ 'XS' } = 'OK';
};


sub sub_update
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $data   =    $mi->{ 'DATA'   };
  my $id     =    $mi->{ 'ID'     };
  my $lock   =    $mi->{ 'LOCK'   } ? 1 : 0;
  my $filter =    $mi->{ 'FILTER' } || {};

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid DATA [$data]"           unless ref( $data ) eq 'HASH';
  boom "invalid ID [$id]"               if $id ne '' and ! de_check_id( $id );
  boom "invalid FILTER [$filter]"       unless ref( $filter ) eq 'HASH';

  my $profile = subs_get_current_profile();
  boom "E_ACCESS: user group 967 has global write restriction" if ! $profile->has_root_access() and $profile->check_access( 967 ); # FIXME: move to common
  boom "E_ACCESS: access denied oper [UPDATE] for table [$table]" unless $profile->check_access_table( 'UPDATE', $table );

  my $rec = new Decor::Core::DB::Record;

  $rec->set_profile_locked( $profile );

  $rec->taint_mode_enable_all();

  my ( $where, $bind ) = __filter_to_where( $id > 0 ? { '_ID' => $id } : $filter );
  my $where_clause = join ' AND ', @$where;

  boom "E_ACCESS: unable to load requested record TABLE [$table] ID [$id]"
      unless $rec->select_first1( $table, $where_clause, { BIND => $bind, LOCK => $lock } );

  # TODO: check RECORD UPDATE ACCESS
  boom "E_ACCESS: UPDATE is not allowed for requested record TABLE [$table] ID [$id]"
      unless $profile->check_access_row( 'UPDATE', $rec->table(), $rec );

  $rec->write( %$data );

  $rec->taint_mode_disable_all();
  __sub_attach_edit_cache_sid_to_rec( $mi, $rec );
  $rec->__client_io_enable();
  $rec->method( 'UPDATE' );
  $rec->edit_cache_save();

  $rec->save();

  $rec->inject_return_file_into_mo( $mo );

  $mo->{ 'XS' } = 'OK';
};


sub sub_delete
{
  my $mi = shift;
  my $mo = shift;

  my $profile = subs_get_current_profile();
  boom "E_ACCESS: user group 967 has global write restriction" if ! $profile->has_root_access() and $profile->check_access( 967 ); # FIXME: move to common
  boom "sub_delete is not yet implemented";
};

sub sub_recalc
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc   $mi->{ 'TABLE'  };
  my $data   =      $mi->{ 'DATA'   };
  my $id     =      $mi->{ 'ID'     };
  my $insert = 1 if $mi->{ 'INSERT' };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid ID [$id]"               if $id ne '' and ! de_check_id( $id );

  my $rec = new Decor::Core::DB::Record;

  my $profile = subs_get_current_profile();
  $rec->set_profile_locked( $profile );

  $rec->taint_mode_on( 'TABLE', 'ROWS' );

  if( $insert )
    {
    $rec->create_read_only( $table, $id );
    }
  else
    {
    $rec->load( $table, $id );
    }

  $rec->write( %$data );

  $rec->taint_mode_disable_all();

  # TODO: recalc for insert/update
  __sub_attach_edit_cache_sid_to_rec( $mi, $rec );
  $rec->__client_io_enable();
  $rec->method( 'RECALC' );
  $rec->method( $insert ? 'RECALC_INSERT' : 'RECALC_UPDATE' );
  $rec->edit_cache_save();

  $rec->inject_return_file_into_mo( $mo );

  my $merrs = $rec->method_get_errors_hashref();
  $mo->{ 'MERRS' } = $merrs if $merrs;
  $mo->{ 'RDATA' } = $rec->read_hash_all();
  $mo->{ 'XS'    } = 'OK';
#print Dumper( $rec, $mi, $mo  );
}

sub sub_do
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $do     =    $mi->{ 'DO'     };
  my $data   =    $mi->{ 'DATA'   };
  my $id     =    $mi->{ 'ID'     };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid DO name [$do]"          unless de_check_name( $do ) or ! des_exists_category( 'DO', $table, $do );
  boom "invalid DATA [$data]"           unless ref( $data ) eq 'HASH';
  boom "invalid ID [$id]"               unless $id eq '' or de_check_id( $id );

  my $profile = subs_get_current_profile();
  boom "E_ACCESS: user group 967 has global write restriction" if ! $profile->has_root_access() and $profile->check_access( 967 ); # FIXME: move to common
  boom "E_ACCESS: access denied do [$do] for table [$table]" unless $profile->check_access_table_category( 'EXECUTE', $table, 'DO', $do );

  my $rec = new Decor::Core::DB::Record;

  $rec->set_profile_locked( $profile );

  $rec->taint_mode_on( 'TABLE', 'ROWS' );

  if( $id )
    {
    $rec->load( $table, $id );
    }
  else
    {
    $rec->create_read_only( $table );
    }

  # $rec->write( %$data );

  $rec->taint_mode_disable_all();

  # TODO: recalc for insert/update
  $rec->__client_io_enable();
  $rec->method( uc "DO_$do" );
  $rec->save();

  $rec->inject_return_file_into_mo( $mo );

  #$mo->{ 'MERRS' } = $rec->{ 'METHOD:ERRORS' } if $rec->{ 'METHOD:ERRORS' };
  #$mo->{ 'RDATA' } = $rec->read_hash_all();
  $mo->{ 'XS'    } = 'OK';
#print Dumper( $rec, $mi, $mo  );
}

sub sub_access
{
  my $mi = shift;
  my $mo = shift;
  
  my $table  = uc $mi->{ 'TABLE'  };
  my $id     =    $mi->{ 'ID'     };
  my $oper   = uc $mi->{ 'OPER'   };
  my $data   =    $mi->{ 'DATA'   }; # not supported yet

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid DATA [$data]"           if $data and ref( $data ) ne 'HASH';
  boom "invalid ID [$id]"               unless de_check_id( $id );
  boom "invalid OPER [$oper]"           unless de_check_name( $oper );

  boom "E_ACCESS: invalid oper [$oper]" unless exists { 'READ' => 1, 'UPDATE' => 1, 'DELETE' => 1, }->{ $oper };

  my $profile = subs_get_current_profile();
  boom "E_ACCESS: access denied oper [$oper] for table [$table]" unless $profile->check_access_table( $oper, $table );
  
  boom "E_ACCESS: access denied: invalid record ID [$id] for table [$table]" unless $id > 0;

  my $rec = new Decor::Core::DB::Record;

  $rec->set_profile_locked( $profile );

  $rec->taint_mode_enable_all();

  boom "E_ACCESS: unable to load requested record TABLE [$table] ID [$id]"
      unless $rec->select_first1( $table, "_ID = ?", { BIND => [ $id ] } );

  boom "E_ACCESS: record access denied oper [$oper] for table [$table] ID [$id]"
      unless $profile->check_access_row( $oper, $rec->table(), $rec );

  boom "E_ACCESS: method access denied oper [$oper] for table [$table] ID [$id]"
      if $rec->method_exists( 'ACCESS' ) and ! $rec->method( 'ACCESS', $oper );
  
  $mo->{ 'XS'    } = 'OK';
}

sub sub_file_save
{
  my $mi = shift;
  my $mo = shift;
  my $socket = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $id     =    $mi->{ 'ID'     };
  my $name   =    $mi->{ 'NAME'   };
  my $mime   =    $mi->{ 'MIME'   };
  my $size   =    $mi->{ 'SIZE'   };
  my $fdes   =    $mi->{ 'DES'    };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid ID [$id]"               if $id ne '' and ! de_check_id( $id );
  boom "invalid SIZE [$size]"           unless $size > 0;

  my $profile = subs_get_current_profile();
  my $rec = new Decor::Core::DB::Record;
  $rec->set_profile_locked( $profile );
  $rec->taint_mode_enable_all();

  my $des = describe_table( $table );
  boom "E_ACCESS: FILE_SAVE access denied, table [$table] is not of type FILE" unless $des->get_table_type() eq 'FILE';
  
  if( $id ne '' )
    {
    $rec->select( $table, '_ID = ?', { BIND => [ $id ] } );
    if( $rec->next() )
      {
      boom "E_ACCESS: FILE_SAVE access denied oper [UPDATE] for table [$table]" unless $profile->check_access_table( 'UPDATE', $table );
      boom "E_ACCESS: FILE_SAVE access denied oper [UPDATE] for table [$table] record ID [$id]" unless $profile->check_access_row( 'UPDATE', $rec->table(), $rec );
      }
    else
      {
      boom "E_NOT_FOUND: FILE_LOAD access denied, FILE ID [$id] not found";
      }  
    }
  else
    {
    boom "E_ACCESS: FILE_SAVE access denied oper [INSERT] for table [$table]" unless $profile->check_access_table( 'INSERT', $table );
    $rec->create( $table );
    }

  $rec->taint_mode_disable_all();
  $rec->write( NAME => $name, MIME => $mime, SIZE => $size, DES => $fdes );
  
  my ( $fname, $fname_short ) = $rec->get_file_name();
  my $fname_part = $fname . '.part';

  if( ! $mime )
    {
    eval { require File::MimeInfo; };
    if( ! $@ )
      {
      $mime = File::MimeInfo::mimetype( $fname );
      $rec->write( MIME => $mime );
      }
    }
  
  $rec->write( SYS_FNAME => $fname_short );

  # FIXME: move to server IO like in Client IO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  open( my $fo, '>', $fname_part );
  binmode( $fo );
  my $buf_size = 1024*1024;
  my $read;
  my $file_size = $size;
  while(4)
    {
    my $data;
    my $read_size = $file_size > $buf_size ? $buf_size : $file_size;
    $read = socket_read( $socket, \$data, $read_size );
    print $fo $data;
    last unless $read > 0;
    $file_size -= $read;
    last if $file_size <= 0;
    }
  close( $fo );

  $rec->method( 'FILE_SAVE' );

  $rec->save();
  rename( $fname_part, $fname );

  $mo->{ 'ID'   } = $rec->id();
  $mo->{ 'XS'   } = 'OK';
  
  return 1;
}

sub sub_file_load
{
  my $mi = shift;
  my $mo = shift;
  my $socket = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $id     =    $mi->{ 'ID'     };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid ID [$id]"               unless de_check_id( $id );

  my $profile = subs_get_current_profile();
  my $rec = new Decor::Core::DB::Record;
  $rec->set_profile_locked( $profile );
  $rec->taint_mode_enable_all();

  my $des = describe_table( $table );
  boom "E_ACCESS: FILE_LOAD access denied, table [$table] is not of type FILE" unless $des->get_table_type() eq 'FILE';

  boom "E_ACCESS: FILE_LOAD access denied oper [READ] for table [$table]" unless $profile->check_access_table( 'READ', $table );

  
  $rec->select( $table, '_ID = ?', { BIND => [ $id ] } );
  if( $rec->next() )
    {
    boom "E_ACCESS: FILE_LOAD access denied oper [READ] for table [$table] record ID [$id]" unless $profile->check_access_row( 'READ', $rec->table(), $rec );
    }
  else
    {
    boom "E_NOT_FOUND: FILE_LOAD access denied, FILE ID [$id] not found";
    }  

  my ( $name, $mime, $size ) = $rec->read( qw( NAME MIME SIZE ) );
  
  my $fname = $rec->get_file_name();

  $size = -s $fname; # physical file size is always better than database saved one :)

  $mo->{ '___SEND_FILE_NAME' } = $fname;
  $mo->{ '___SEND_FILE_SIZE' } = $size;

  $mo->{ 'NAME' } = $name;
  $mo->{ 'MIME' } = $mime;
  $mo->{ 'SIZE' } = $size;
  $mo->{ 'ID'   } = $rec->id();
  $mo->{ 'XS'   } = 'OK';
  
  return 1;
}

#--- CONTROLS/COMMIT/ROLLBACK/ETC. -------------------------------------------

sub sub_begin_work
{
  my $mi = shift;
  my $mo = shift;

  subs_enable_manual_transaction();
  dsn_begin_work();

  $mo->{ 'XS' } = 'OK';
}

sub sub_commit
{
  my $mi = shift;
  my $mo = shift;

  subs_disable_manual_transaction();
  dsn_commit();

  $mo->{ 'XS' } = 'OK';
};


sub sub_commit
{
  my $mi = shift;
  my $mo = shift;

  subs_disable_manual_transaction();
  dsn_commit();

  $mo->{ 'XS' } = 'OK';
};


sub sub_rollback
{
  my $mi = shift;
  my $mo = shift;

  subs_disable_manual_transaction();
  dsn_rollback();

  $mo->{ 'XS' } = 'OK';
};

### EOF ######################################################################
1;
