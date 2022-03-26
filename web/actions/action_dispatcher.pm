package decor::actions::action_dispatcher;
use strict;

sub main
{
  my $reo = shift;

  my $si = $reo->get_safe_input();   # safe input
  my $ui = $reo->get_user_input();   # user input
  my $ps = $reo->get_page_session(); # page session data

  my $action = lc( $si->{ 'ACTION' } ) || lc( $ui->{ 'ACTION' } ) || $ps->{ 'ACTION' } || 'home';

  $reo->log_debug( "*** ACTION_DISPATCHER: selected action is [$action]" );

  my $text;

  if( $action =~ /^[a-z_0-9]+$/ )
    {
    $ps->{ 'ACTION' } = $action unless exists $ps->{ 'ACTION' } and $ps->{ 'ACTION' } eq $action; # avoid writing to session storage

    my $act = $reo->act->call( $action );
    $reo->html_content( 'main_action' => $act );
    }
  else
    {
    $reo->log( "error: invalid action/page received [$action] redirect to home" );
    }

  return $text;
}

1;
