##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  Web::Reactor application machinery
##  2013-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Web::Reactor::Decor;
use strict;
use Exporter;
use Web::Reactor 2.09;
use Exception::Sink;
use Data::Tools;
use Data::Dumper;
use Storable;

use Decor::Shared::Net::Client;
use Decor::Shared::Utils;
use Decor::Shared::Config;
use Decor::Shared::Types;
use Decor::Web::Utils;

our @ISA = qw( Web::Reactor );

sub de_re_app_dir
{
  my $ROOT     = shift;
  my $APP_NAME = shift;
  # TODO: move app dir entirely out of decor dir structure
  for( "$ROOT/apps/$APP_NAME", "$ROOT/apps/$APP_NAME-app-decor", "$ROOT/apps/decor-app-$APP_NAME" )
    {
    return $_ if -d 
    }
  return undef;
}

sub new
{
  my $class = shift;
  my $env   = shift;
  my $cfg   = shift;

  $class = ref( $class ) || $class;

  my $ROOT     = $cfg->{ 'DECOR_CORE_ROOT' } || '/usr/local/decor/';

  boom "ROOT path does not exist [$ROOT]" unless -d $ROOT;

  my $APP_NAME = lc $cfg->{ 'APP_NAME' };

  boom "missing APP_NAME" unless $APP_NAME =~ /^[a-z_0-9]+$/;

  my $APP_ROOT  = de_re_app_dir( $ROOT, $APP_NAME ) or boom "APP_ROOT path does not exist [$ROOT] app name [$APP_NAME]";

  my $lang = lc $cfg->{ 'LANG' } || 'en';
  
  boom "invalid LANG specified, got [$lang]" unless $lang =~ /^[a-z][a-z]$/;

  my %cfg = (
            'DEBUG'          => 0,
            'APP_NAME'       => $APP_NAME,
            'APP_ROOT'       => $APP_ROOT,
            'LIB_DIRS'       => [ "$APP_ROOT/web/lib", "$APP_ROOT/lib", "$ROOT/shared/lib", "$ROOT/web/lib" ],
            'HTML_DIRS'      => $lang ?
                                    [
                                      "$APP_ROOT/web/html/$lang/",
                                      "$ROOT/web/html/$lang/",
                                      "$APP_ROOT/web/html/default/",
                                      "$ROOT/web/html/default/"
                                    ]
                                :
                                    [
                                      "$APP_ROOT/web/html/default/",
                                      "$ROOT/web/html/default/"
                                    ],
            'ACTIONS_DIRS'   => [ "$APP_ROOT/web/actions", "$ROOT/web/actions" ],
            'REO_ACT_CLASS' => 'Web::Reactor::Actions::Decor',
            'REO_PRE_CLASS' => 'Web::Reactor::Preprocessor::Extended',
            #'TRANS_DIRS'     => [ "$ROOT/web/trans", "$APP_ROOT/web/trans" ],
            'TRANS_FILE'     => "$APP_ROOT/web/trans/$lang/$lang.tr",
            'SESS_VAR_DIR'   => "$ROOT/var/$APP_NAME/sess/",
            %$cfg,
            );

  type_set_format( $_, $cfg->{ "FMT_$_" } ) for qw( DATE TIME UTIME );

  return $class->Web::Reactor::new( $env, \%cfg );
}

#-----------------------------------------------------------------------------

sub load_trans_file
{
  my $self = shift;

  return tr_hash_load( shift );
}

#-----------------------------------------------------------------------------

sub __setup_client_env
{
  my $self   = shift;
  my $client = shift;
  
  my $user_shr = $self->get_user_session();

  $user_shr->{ 'DECOR_CORE_SESSION_ID' } = $client->{ 'DECOR_CORE_SESSION_ID' };
  $user_shr->{ 'USER_GROUPS'           } = $client->{ 'USER_GROUPS' } || {};
  $user_shr->{ 'USER_NAME'             } = $client->{ 'USER_NAME'   } || {};
  
  $self->html_content( 'USER_NAME' => $user_shr->{ 'USER_NAME' } );
  
  $self->set_user_session_expire_time( $client->{ 'CORE_SESSION_XTIME' } );
}

sub de_connect
{
  my $self = shift;

  my %opt = @_;

  return $self->{ 'DECOR_CLIENT_OBJECT' } if $self->{ 'DECOR_CLIENT_OBJECT' } and $self->{ 'DECOR_CLIENT_OBJECT' }->is_connected();

  my $cfg = $self->get_cfg();

  my $de_core_app     = $cfg->{ 'DECOR_CORE_APP'       };
  my $de_core_host    = $cfg->{ 'DECOR_CORE_HOST'      };
  my $de_core_timeout = $cfg->{ 'DECOR_CORE_TIMEOUT'   } || 64;
  my $lang            = $cfg->{ 'LANG' };

  my $user_shr = $self->get_user_session();
  my $http_env = $self->get_http_env();
  my $remote   = $self->get_client_ip();

  my $de_core_session_id = $user_shr->{ 'DECOR_CORE_SESSION_ID' } || 'CREATE';

  my $client = Decor::Shared::Net::Client->new( TIMEOUT => $de_core_timeout );

  $self->log( "debug: {$client} about to connect to [$de_core_host] app [$de_core_app] with core session [$de_core_session_id]" );

  if( ! $client->connect( $de_core_host, $de_core_app ) )
    {
    $self->log( "error: connect FAILED to host [$de_core_host] application [$de_core_app]:\n" . Dumper( $client ) );
    return $self->render( PAGE => 'error', 'main_action' => "<#e_connect>" );
    }


  if( $client->begin( $de_core_session_id, $remote ) )
    {
    $self->log( "status: connect OK with session [$de_core_session_id] remote [$remote]" );
    $self->__setup_client_env( $client );
    $self->{ 'DECOR_CLIENT_OBJECT' } = $client;
    return $client;
    }
  else  
    {
    $self->log( "error: connect FAILED to host [$de_core_host] application [$de_core_app]:\n" . Dumper( $client ) );
    my $status = $client->status();
    $self->logout();
    return $self->render( PAGE => 'error', 'main_action' => "<#$status>" );
    }
}

#-----------------------------------------------------------------------------

sub de_login
{
  my $self   = shift;
  my $user   = shift;
  my $pass   = shift;

  my $user_shr = $self->get_user_session();
  my $http_env = $self->get_http_env();
  my $remote   = $self->get_client_ip();

  my $client = $self->de_connect() or boom "cannot de_login(), DECOR CLIENT OBJECT is missing";

  $self->log( "debug: {$client} about login as [$user] remote [$remote]" );

  if( $client->login( $user, $pass, $remote ) )
    {
    $self->__setup_client_env( $client );
    my $de_core_session_id = $user_shr->{ 'DECOR_CORE_SESSION_ID' };
    $self->log( "status: login OK as user [$user] remote [$remote] core session [$de_core_session_id]" );
    return 1;
    }
  else
    {
    $self->log( "error: login FAILED as user [$user] remote [$remote]:\n" . Dumper( $client ) );
    return undef;
    }
}

#-----------------------------------------------------------------------------

sub de_logout
{
  my $self   = shift;

  my $client = $self->de_connect() or boom "cannot de_logout(), DECOR CLIENT OBJECT is missing";
  
  $client->logout();
  $self->logout();
  
  delete $self->{ 'DECOR_CLIENT_OBJECT' };
  return 1;
}

#-----------------------------------------------------------------------------

sub de_load_cfg
{
  my $self = shift;

  my $fn = shift;
  boom "invalid config file name" unless $fn =~ /^[a-zA-Z0-9_]+$/;

  my $app_root = $self->get_app_root();

  my $fnf = "$app_root/web/etc/$fn.cfg";
  $self->log( "error: config file not found [$fnf]" ) unless -e $fnf;
  my $cfg = de_config_load_file( $fnf );

  return $cfg;
}

#-----------------------------------------------------------------------------

sub ps_path_add
{
  my $self  =    shift;
  my $icon  = lc shift;
  my $title =    shift;

  my $ps    = $self->get_page_session();
  my $rs    = $self->get_page_session( 1 );
  my $ps_id = $self->get_page_session_id();

  my @ps_path = @{ $rs->{ 'PS_PATH' } || [] };
  $ps->{ 'PS_PATH' } = \@ps_path;

  $icon .= '.svg' unless $icon =~ /\.(png|gif|jpg|jpeg)$/i;

  push @ps_path, { PS_ID => $ps_id, ICON => $icon, TITLE => $title };
  
  $self->set_browser_window_title( $title );

  return @ps_path;
}

sub ps_path_add_by_cue
{
  my $self  = shift;
  my $des    =    shift;
  my $action = uc shift; # also icon

  my ( $title, $hint ) = de_web_get_cue( $des, 'WEB', $action, "${action}_CUE" );
  $title =~ s|\*(.+?)\*|<b>$1</b>|g;
  $hint  =~ s|\*(.+?)\*|<b>$1</b>|g;
  $self->ps_path_add( $action, $title );
  
  return wantarray ? ( $title, $hint ) : $title;
}


### user related helpers #####################################################

sub user_has_group
{
  my $self  = shift;
  my $group = shift;

  my $user_shr = $self->get_user_session();
  return undef unless exists $user_shr->{ 'USER_GROUPS' };
  return undef unless exists $user_shr->{ 'USER_GROUPS' }{ $group };
  return $user_shr->{ 'USER_GROUPS' }{ $group };
}

#-----------------------------------------------------------------------------

1;
