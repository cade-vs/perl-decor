package decor::actions::page_expire_hint;
use strict;

sub main
{
  my $reo = shift;

  my $text;

  return undef unless $reo->is_logged_in();
  return undef unless $reo->get_user_session_expire_time();

  my $expire_time = $reo->get_user_session_expire_time() - time();

  return undef if $exp_time < 1;

  $text .= <<END;

  <small id=page_expire_time_hint></small>

  <script type="text/javascript">

  var page_expire_time    = $expire_time;
  var page_expire_timeout = 4;

  function report_page_expire_time()
  {
    var el = document.getElementById( 'page_expire_time_hint' );

    if( page_expire_time > 0 )
      {
      var m = Math.floor( page_expire_time / 60 );
      var s = Math.floor( page_expire_time % 60 );
      el.innerHTML = '<~page expires in> ';
      if( m >  0 ) el.innerHTML += m + '<~min>';
      if( m <= 0 ) el.innerHTML += s + '<~sec>';
      setTimeout( 'report_page_expire_time()', page_expire_timeout * 1000 );
      page_expire_time -= page_expire_timeout;
      }
    else
      {
      el.innerHTML = '<span class=warning>page expired</span>'
      }
  }

  report_page_expire_time();

  </script>

END

  return $text;
}

1;
