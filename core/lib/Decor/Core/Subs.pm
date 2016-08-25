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
use Decor::Core::Subs::Env;

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

  $BEGIN_SALT = create_random_id();
  $mo->{ 'LOGIN_SALT'  } = $BEGIN_SALT;
  
  my $user = $mi->{ 'USER' };
  if( $user )
    {
    my $user_rec = __sub_find_user( $user );
    $mo->{ 'USER_SALT'  } = $user_rec->read( 'PASS_SALT' );
    }
  
  $mo->{ 'XS'    } = 'OK';
  return 1;
}

sub sub_begin
{
  my $mi = shift;
  my $mo = shift;

  my $user = $mi->{ 'USER' }
  my $pass = $mi->{ 'PASS' }
  
  # user/pass login
  if( $user and $login )
    {
    return __sub_begin_with_user_pass( $user, $pass );
    }
  
  my $user_sid = $mi->{ 'USER_SID' }

  # session continue
  if( $user_sid )
    {
    # TODO: param/ip/addr
    return __sub_begin_with_session_continue( $user_sid );
    }
  
};

sub __sub_begin_with_user_pass
{
  my $user = shift;
  my $pass = shift;
  
  my $begin_salt = $BEGIN_SALT;
  $BEGIN_SALT = undef;
  boom "login seed is empty, call XT=BEGIN_PREPARE first" unless $LOGIN_SALT;
  subs_lock_current_user( __sub_find_and_check_user_pass( $user, $pass ) );

  my $user = subs_get_current_user();

  # TODO: allow/deny root login
  die "E_LOGIN: User not active" unless $user->read( 'ACTIVE' ) > 0;

  $mo->{ 'XS'    } = 'OK';
  return 1;
}

sub __sub_begin_with_session_continue
{
  my $user_sid = shift;
  
  return 1;
}

sub __sub_find_user
{
  my $user_name = shift;

  boom "E_LOGIN: Invalid user login name [$user_name]" unless de_check_user_login_name(  $user_name );

  my $user_rec = new Decor::DB::Record;

  $user_rec->select( 'DE_USERS', 'NAME = ?', { BIND => [ $user_name ] } );
  if( $user_rec->fetch() )
    {
    return $user_rec;
    }
  boom "E_LOGIN: User not found [$user_name]";
  return undef; # never reached
}

sub __sub_find_and_check_user_pass
{
  my $user = shift;
  my $pass = shift; # expected to be whirlpool_hex( "$SEED:$wp_hex_pass" )
  my $salt = shift;

  my $user_rec = __sub_find_user( $user );
  
  boom "E_LOGIN: Invalid user [$user] password"   unless de_check_user_pass_digest( $pass );
  
  if( $user_rec->fetch() )
    {
    my $user_pass = $user_rec->read( 'PASS' );
    # TODO: use configurable digests
    my $user_pass_hex = wp_hex( "$salt:$pass" ); 
    boom "E_LOGIN: Wrong user [$user] password"   unless $pass eq $user_pass_hex;
    return $user_rec;
    }
  boom "E_LOGIN: User not found [$user]";
}

sub sub_end
{
  my $mi = shift;
  my $mo = shift;
  
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
