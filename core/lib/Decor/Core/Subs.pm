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

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Core::Subs::Env;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::Menu;

use Clone qw( clone );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                subs_process_xt_message

                );

# TODO: op triggers

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
                                   'NEXTID'   => \&sub_get_next_id,
                                   'INSERT'   => \&sub_insert,
                                   'UPDATE'   => \&sub_update,
                                   'DELETE'   => \&sub_delete,
                                   'RECALC'   => \&sub_recalc,
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
                    'L'   => 'RECALC',
                    'M'   => 'MENU',
                    'N'   => 'NEXTID',
                    'P'   => 'PREPARE',
                    'R'   => 'ROLLBACK',
                    'S'   => 'SELECT',
                    'T'   => 'DELETE',
                    'U'   => 'UPDATE',
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
                    'eq'   => '=',
                    'lt'   => '<',
                    'le'   => '<=',
                    'gt'   => '>',
                    'ge'   => '>=',
                    'ne'   => '<>',
                    );


my %SELECT_MAP;
my $SELECT_MAP_COUNTER;
my $SELECT_MAP_COUNT;

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

  de_log_debug( "debug: processing XTYPE [$xt] xt code handle [$handle]" );

  my $res = $handle->( $mi, $mo );
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

sub sub_reset
{
  my $mi = shift;
  my $mo = shift;

  __sub_reset_state();
  
  $mo->{ 'XS'    } = 'OK';
  return 1;
};

sub __sub_reset_state
{
  subs_reset_dispatch_map();
  subs_reset_current_all();
  %SELECT_MAP = ();
  $SELECT_MAP_COUNTER = 0;
  $SELECT_MAP_COUNT   = 0;
}

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
    boom "invalid XT=BEGIN parameters";
    }  

  my $user = subs_get_current_user();
  my $sess = subs_get_current_session();
  
  my $sess_sid = $sess->read( 'SID' );
  
  my $profile = new Decor::Core::Profile;
  $profile->add_groups_from_user( $user );
  
  # common groups setup
  $profile->add_groups( 999 ); # all/everybody
  $profile->remove_groups( 900, 901 ); # nobody
  
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
      de_log_debug( "debug: error: session create hit existing session, retry" );
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
  
  die "E_LOGIN: User not active [$user]"         unless $user_rec->read( 'ACTIVE' );
  die "E_LOGIN: Invalid user [$user] password"   unless de_check_user_pass_digest( $pass );
  
  my $user_pass = $user_rec->read( 'PASS' );
  # TODO: use configurable digests
  my $user_pass_hex = de_password_salt_hash( $user_pass, $salt ); 
  die "E_LOGIN: Wrong user [$user] password"   unless $pass eq $user_pass_hex;
  return $user_rec;
};

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

# i.e. logout
sub sub_end
{
  my $mi = shift;
  my $mo = shift;

  #my $user_sid = $mi->{ 'USER_SID' };
  #my $remote   = $mi->{ 'REMOTE'   };

  #my $sess = __sub_find_session( $user_sid, $remote );

  my $session_rec = subs_get_current_session();
  
  $session_rec->write(
                     'ACTIVE' => 0,
                     'ETIME'  => time(),
                     'ATIME'  => time(),
                     );
  $session_rec->save();

  __sub_reset_state();
  
  $mo->{ 'XS'    } = 'OK';
};

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
    return 1;
    }
  
  for my $grant_deny ( qw( GRANT DENY ) )
    {
    if( ! $hrd->{ $grant_deny } )
      {
      $hrn->{ $grant_deny } = {};
      next;
      }
    while( my ( $k, $v ) = each %{ $hrd->{ $grant_deny } } )
      {
      $hrn->{ $grant_deny }{ $k } = $profile->__check_access_tree( $k, $hrd->{ $grant_deny } );
      }
    }  

  for my $oper ( keys %{ $hrn->{ 'DENY' } } )
    {
    next unless $hrn->{ 'DENY' }{ $oper };
    delete $hrn->{ 'GRANT' }{ $oper };
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

  __replace_grant_deny( $profile, $new->{ '@' }, $des->{ '@' } );
  delete $new->{ 'INDEX' };

  for my $field ( @{ $new->{ '@' }{ '_FIELDS_LIST' } } )
    {
    my $hrd = $des->{ 'FIELD' }{ $field };
    my $hrn = $new->{ 'FIELD' }{ $field };
    #dunlock $hr;
    #dunlock $hr->{ 'DENY'  };
    __replace_grant_deny( $profile, $hrn, $hrd );
    delete $hrn->{ 'DEBUG::ORIGIN' };
    }
  
  $mo->{ 'DES'   } = $new;
  $mo->{ 'XS'    } = 'OK';
};

sub sub_menu
{
  my $mi = shift;
  my $mo = shift;

  my $menu_name = $mi->{ 'MENU' };

  boom "invalid MENU name [$menu_name]"   unless de_check_name( $menu_name );

  my $profile = subs_get_current_profile();

  my $menu = de_menu_get( $menu_name );

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
    if( $vref eq 'HASH' )
      {
      my $op  = uc $v->{ 'OP'    };
      my $val =    $v->{ 'VALUE' };
      boom "invalid OPERATOR [$op]" unless exists $SELECT_WHERE_OPERATORS{ $op };
      my $op = $SELECT_WHERE_OPERATORS{ $op };

      push @where, ".$f $op ?";
      push @bind,  $val;
      }
    elsif( $vref eq 'ARRAY' )  
      {
      # i.e. IN
      my $vc = @$v;
      my @inph = ( '?' ) x $vc; # IN place holders
      my $inph = join ',', @inph;

      push @where, ".$f IN ( $inph )";
      push @bind,  @$v;
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

  # FIXME: TODO: Subs/MessageCheck TABLE ID FIELDS LIMIT OFFSET FILTER validate_hash()
  boom "invalid TABLE name [$table]"    unless de_check_name( $table );
  boom "invalid FIELDS list [$fields]"  unless $fields   =~ /^([A-Z_0-9\.\,]+|COUNT\(\*\)|\*)$/o; # FIXME: more aggregate funcs
  boom "invalid ORDER BY [$order_by]"   unless $order_by =~ /^([A-Z_0-9\. ]*)$/o;
  boom "invalid GROUP BY [$group_by]"   unless $group_by =~ /^([A-Z_0-9\. ]*)$/o;
  boom "invalid LIMIT [$limit]"         unless $limit    =~ /^[0-9]*$/o;
  boom "invalid OFFSET [$offset]"       unless $offset   =~ /^[0-9]*$/o;
  boom "invalid FILTER [$filter]"       unless ref( $filter ) eq 'HASH';

  # TODO: check TABLE READ ACCESS
 
  my ( $where, $bind ) = __filter_to_where( $filter );
  my $where_clause = join ' AND ', @$where;

  my $profile = subs_get_current_profile();
  
  my $select_handle;
  # $select_handle = create_random_id( 64 ) while $SELECT_MAP{ $select_handle };
  $SELECT_MAP_COUNTER++;
  $SELECT_MAP_COUNT++;
  $select_handle = $SELECT_MAP_COUNTER;
  my $dbio = $SELECT_MAP{ $select_handle } = new Decor::Core::DB::IO;
  $dbio->set_profile_locked( $profile );
  $dbio->taint_mode_enable_all();
  
  my $res = $dbio->select( $table, $fields, $where_clause, { BIND => $bind, LIMIT => $limit, OFFSET => $offset, ORDER_BY => $order_by, GROUP_BY => $group_by } );
  
  $mo->{ 'SELECT_HANDLE' } = $select_handle;
  $mo->{ 'XS'            } = 'OK';
};


sub sub_fetch
{
  my $mi = shift;
  my $mo = shift;

  my $select_handle = $mi->{ 'SELECT_HANDLE' };
  boom "invalid SELECT_HANDLE [$select_handle]" unless exists $SELECT_MAP{ $select_handle };
  my $dbio = $SELECT_MAP{ $select_handle };

  my $hr = $dbio->fetch();
  
  if( $hr )
    {
    $mo->{ 'DATA' } = $hr;
    $mo->{ 'XS'   } = 'OK';
    }
  else
    {
    $mo->{ 'EOD'  } = 'YES'; # end of data
    $mo->{ 'XS'   } = 'OK';
    }  
};


sub sub_finish
{
  my $mi = shift;
  my $mo = shift;

  my $select_handle = $mi->{ 'SELECT_HANDLE' };
  boom "invalid SELECT_HANDLE [$select_handle]" unless exists $SELECT_MAP{ $select_handle };
  my $dbio = $SELECT_MAP{ $select_handle };
  
  $dbio->finish();
  delete $SELECT_MAP{ $select_handle };
  $SELECT_MAP_COUNT--;
  if( $SELECT_MAP_COUNT <= 0 )
    {
    $SELECT_MAP_COUNT   = 0;
    $SELECT_MAP_COUNTER = 0;
    }
  
  $mo->{ 'XS' } = 'OK';
};

#--- INSERT/UPDATE/DELETE ----------------------------------------------------

sub sub_get_next_id
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table );

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

  boom "invalid TABLE name [$table]"    unless de_check_name( $table );
  boom "invalid DATA [$data]"           unless ref( $data ) eq 'HASH';
  boom "invalid ID [$id]"               unless de_check_id( $id );

  # TODO: check TABLE INSERT ACCESS

  if( $id > 0 )
    {
    # TODO: check reserved IDs
    my $user = subs_get_current_user();
    my $sess = subs_get_current_session();
  
    my $user_id = $user->id();
    my $sess_id = $sess->id();
    
    my $res_rec = new Decor::Core::DB::Record;
    
    boom "E_ACCESS: invalid RESERVED_ID [$id] for table [$table] user [$user_id] session [$sess_id]" 
        unless $res_rec->select_first1( 'DE_RESERVED_IDS', 'USR = ? AND SESS = ? AND RESERVED_TABLE = ? AND RESERVED_ID = ? AND ACTIVE = ?', { BIND => [ $user_id, $sess_id, $table, $id, 1 ] } );
    
    $res_rec->write(
                    'ETIME'       => time(),
                    'ACTIVE'      => 0,
                   );
    $res_rec->save();
    $data->{ '_ID' } = $id;
    }
  else
    {
    my $dbio = new Decor::Core::DB::IO;
    $id = $dbio->get_next_table_id( $table );
    }  


  my $rec = new Decor::Core::DB::Record;

  my $profile = subs_get_current_profile();
  $rec->set_profile_locked( $profile );

  $rec->taint_mode_enable_all();

  $rec->create( $table, $id );
  $rec->write( %$data );

  $rec->taint_mode_disable_all();
  $rec->method( 'UPDATE' );

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

  boom "invalid TABLE name [$table]"    unless de_check_name( $table );
  boom "invalid DATA [$data]"           unless ref( $data ) eq 'HASH';
  boom "invalid ID [$id]"               unless de_check_id( $id );
  boom "invalid FILTER [$filter]"       unless ref( $filter ) eq 'HASH';

  # TODO: check TABLE UPDATE ACCESS

  my $rec = new Decor::Core::DB::Record;

  my $profile = subs_get_current_profile();
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
  $rec->method( 'UPDATE' );

  $rec->save();

  $mo->{ 'XS' } = 'OK';
};


sub sub_delete
{
  my $mi = shift;
  my $mo = shift;

  boom "sub_delete is not yet implemented";
  
};

sub sub_recalc
{
  my $mi = shift;
  my $mo = shift;

  my $table  = uc $mi->{ 'TABLE'  };
  my $data   =    $mi->{ 'DATA'   };
  my $id     =    $mi->{ 'ID'     };

  my $rec = new Decor::Core::DB::Record;

  my $profile = subs_get_current_profile();
  $rec->set_profile_locked( $profile );

  $rec->taint_mode_enable_all();

  if( $id )
    {
    $rec->load( $table, $id );
    }
  else
    {
    $rec->create_read_only( $table );
    }  

  $rec->write( %$data );

  $rec->taint_mode_disable_all();

  # TODO: recalc for insert/update
  $rec->method( 'RECALC' );

  $mo->{ 'MERRS' } = $rec->{ 'METHOD:ERRORS' } if $rec->{ 'METHOD:ERRORS' };
  $mo->{ 'RDATA' } = $rec->read_hash_all();
  $mo->{ 'XS'    } = 'OK';
#print Dumper( $rec, $mi, $mo  );
}

#--- CONTROLS/COMMIT/ROLLBACK/ETC. -------------------------------------------

sub sub_commit
{
  my $mi = shift;
  my $mo = shift;

  dsn_commit();

  $mo->{ 'XS' } = 'OK';
};


sub sub_rollback
{
  my $mi = shift;
  my $mo = shift;
  
  dsn_rollback();

  $mo->{ 'XS' } = 'OK';
};


### EOF ######################################################################
1;
