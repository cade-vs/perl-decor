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

our @ISA = qw( Web::Reactor );

sub new
{
  my $class = shift;
  my %env = @_;
  $class = ref( $class ) || $class;

  data_tools_set_file_io_encoding( 'UTF-8' );

  my $ROOT     = $env{ 'DECOR_CORE_ROOT' } || '/usr/local/decor/';

  boom "ROOT path does not exist [$ROOT]" unless -d $ROOT;

  my $APP_NAME = lc $env{ 'APP_NAME' };

  boom "missing APP_NAME" unless $APP_NAME =~ /^[a-z_0-9]+$/;

  my $APP_ROOT  = "$ROOT/apps/$APP_NAME/";

  boom "APP_ROOT path does not exist [$APP_ROOT]" unless -d $APP_ROOT;

  my $lang = lc $env{ 'LANG' };

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
            'REO_ACTS_CLASS' => 'Web::Reactor::Actions::Decor',
            'REO_PREP_CLASS' => 'Web::Reactor::Preprocessor::Extended',
            'TRANS_DIRS'     => [ "$ROOT/trans", "$APP_ROOT/trans" ],
            'SESS_VAR_DIR'   => "$ROOT/var/$APP_NAME/sess/",
            %env,
            );

  my $self = $class->Web::Reactor::new( %cfg );

  return $self;

#  eval { $reo->run(); };
#  if( $@ )
#    {
#    print STDERR "REACTOR CGI EXCEPTION: $@";
#    print "content-type: text/html\n\nsystem is temporary unavailable";
#    }
}

#-----------------------------------------------------------------------------

sub prep_process
{
  my $self = shift;
  my $text = $self->{ 'REO_PREP' }->process(   @_ ) ;

#print STDERR $text, Dumper( $ex ), $text;

  return $text;
};

#-----------------------------------------------------------------------------

sub load_trans_file
{
  my $self = shift;

  return tr_hash_load( shift );
}

#-----------------------------------------------------------------------------

sub de_login
{
  my $self = shift;

  my $user = shift;
  my $pass = shift;
  my %opt  = @_;

  my $de_core_app     = $self->{ 'ENV' }{ 'DECOR_CORE_APP'       };
  my $de_core_host    = $self->{ 'ENV' }{ 'DECOR_CORE_HOST'      };
  my $de_core_timeout = $self->{ 'ENV' }{ 'DECOR_CORE_TIMEOUT'   } || 64;
  my $lang            = $self->{ 'ENV' }{ 'LANG' };

  my $http_env = $self->get_http_env();

  my $client = Decor::Shared::Net::Client->new( TIMEOUT => $de_core_timeout );

  $self->log( "debug: about to connect and login to host [$de_core_host] application [$de_core_app]" );

  if( ! $client->connect( $de_core_host, $de_core_app ) )
    {
    $self->log( "error: connect FAILED to host [$de_core_host] application [$de_core_app]:\n" . Dumper( $client ) );
    return ( undef, 'E_CONNECT' );
    }

  my $remote = $http_env->{ 'REMOTE_ADDR' };
  my $de_core_session_id = $client->begin_user_pass( $user, $pass, $remote );

  if( $de_core_session_id )
    {
    my $user_shr = $self->get_user_session();
    $user_shr->{ 'DECOR_CORE_SESSION_ID' } = $de_core_session_id;
    $user_shr->{ 'USER_GROUPS'           } = $client->{ 'USER_GROUPS' } || {};
    $self->log( "status: login OK as user [$user] remote [$remote] core session [$de_core_session_id]" );
    return ( $client );
    }
  else
    {
    $self->log( "error: login FAILED as user [$user] remote [$remote]:\n" . Dumper( $client ) );
    return ( undef, $client->status() );
    }
}

#-----------------------------------------------------------------------------

sub de_connect
{
  my $self = shift;

  my %opt = @_;

  boom "need to be logged in first" unless $self->is_logged_in();
  
  return $self->{ 'DECOR_CLIENT_OBJECT' } if $self->{ 'DECOR_CLIENT_OBJECT' } and $self->{ 'DECOR_CLIENT_OBJECT' }->is_connected();

  my $de_core_app     = $self->{ 'ENV' }{ 'DECOR_CORE_APP'       };
  my $de_core_host    = $self->{ 'ENV' }{ 'DECOR_CORE_HOST'      };
  my $de_core_timeout = $self->{ 'ENV' }{ 'DECOR_CORE_TIMEOUT'   } || 64;
  my $lang            = $self->{ 'ENV' }{ 'LANG' };

  my $user_shr = $self->get_user_session();
  my $http_env = $self->get_http_env();

  my $de_core_session_id = $user_shr->{ 'DECOR_CORE_SESSION_ID'     };

  boom "missing DECOR_CORE_SESSION_ID" unless $de_core_session_id;

  my $client = Decor::Shared::Net::Client->new( TIMEOUT => $de_core_timeout );

  $self->log( "debug: about to connect and use session to host [$de_core_host] application [$de_core_app]" );

  if( ! $client->connect( $de_core_host, $de_core_app ) )
    {
    $self->log( "error: connect FAILED to host [$de_core_host] application [$de_core_app]:\n" . Dumper( $client ) );
    $self->render( PAGE => 'error', 'main_action' => "<#e_connect>" );
    return undef;
    }

  my $remote = $http_env->{ 'REMOTE_ADDR' };

  my $session_ok = $client->begin_user_session( $de_core_session_id, $remote );

  if( $session_ok )
    {
    $self->log( "status: connect OK with session [$de_core_session_id] remote [$remote]" );
    $self->set_user_session_expire_time( $client->{ 'CORE_SESSION_XTIME' } );

    $self->{ 'DECOR_CLIENT_OBJECT' } = $client;
    return $client;
    }
  else
    {
    my $status = $client->status();
    $self->logout();
    delete $self->{ 'DECOR_CLIENT_OBJECT' };
    $self->log( "error: connect FAILED with session [$de_core_session_id] remote [$remote]:\n" . Dumper( $client ) );

    $self->render( PAGE => 'error', 'main_action' => "<#$status>" );
    return undef;
    }
}

#-----------------------------------------------------------------------------

sub de_load_cfg
{
  my $self = shift;

  my $fn = shift;
  boom "invalid config file name" unless $fn =~ /^[a-zA-Z0-9_]+$/;

  my $app_root = $self->{ 'ENV' }{ 'APP_ROOT' };

  my $fnf = "$app_root/web/etc/$fn.cfg";
  $self->log( "error: config file not found [$fnf]" ) unless -e $fnf;
  my $cfg = de_config_load_file( $fnf );

  return $cfg;
}

#-----------------------------------------------------------------------------

sub ps_path_add
{
  my $self  = shift;
  my $icon  = shift;
  my $title = shift;

  my $ps    = $self->get_page_session();
  my $rs    = $self->get_page_session( 1 );
  my $ps_id = $self->get_page_session_id();

  my @ps_path = @{ $rs->{ 'PS_PATH' } || [] };
  $ps->{ 'PS_PATH' } = \@ps_path;

  $icon .= '.svg' unless $icon =~ /\.(png|gif|jpg|jpeg)$/i;

  push @ps_path, { PS_ID => $ps_id, ICON => $icon, TITLE => $title };
  
  $title =~ s/<[^>]*>//g; # remove HTML if any
  $self->set_browser_window_title( $title );

  return @ps_path;
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
