package decor::actions::page_expire_hint;
use strict;

sub main
{
  my $reo = shift;

  my $text;

  return undef unless $reo->is_debug() or $reo->is_logged_in();
  return undef unless $reo->is_debug() or $reo->get_user_session_expire_time();

  my $core = $reo->de_connect();

  my $expire_time = $reo->get_user_session_expire_time() - time();

  # do not report if below zero (disabled) or above 1 hour
  return undef if ! $reo->is_debug() and ( $expire_time < 1 or $expire_time > 3600 ); 

  $text .= <<END;

  <small id=page_expire_time_hint></small>

  <script type="text/javascript">

  var page_expire_time    = $expire_time;
  var page_expire_timeout = 0;

  function report_page_expire_time()
  {
    var el = document.getElementById( 'page_expire_time_hint' );
    if( ! el ) return;

    page_expire_time -= page_expire_timeout;

    if( page_expire_time > 0 )
      {
      var m = Math.floor( page_expire_time / 60 );
      var s = Math.floor( page_expire_time % 60 );
      var str;
      str = page_expire_time < 60 ? '<span class="warning pulse">' : '<span>';
      str += '<~expire:> ';
      if( m >  0 ) str += m + '<~min>';
      if( m <= 0 ) str += s + '<~sec>';
      str += '</span>';
      el.innerHTML = str;
      page_expire_timeout = ( page_expire_time > 60 ? 20 : 1 );
      setTimeout( 'report_page_expire_time()', page_expire_timeout * 1000 );
      }
    else
      {
      el.innerHTML = '<span class="warning pulse">PAGE EXPIRED!</span>'
      window.location.href = '?';
      }
  }

  report_page_expire_time();

  </script>

END

  return $text;
}

1;
