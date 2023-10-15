package decor::actions::ps_path;
use strict;
use Data::Dumper;
use Data::Tools;
use Decor::Web::HTML::Utils;
use Web::Reactor::HTML::Utils;

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $ps    = $reo->get_page_session();                                                                                            
  my $ps_id = $reo->get_page_session_id();

  my $ps_path = $ps->{ 'PS_PATH' } || [];

  return "<#main_ps_path_tr_hide>" unless @$ps_path > 0;
  
  my $text;
  
  my $path_count = @$ps_path;
  for my $p ( @$ps_path )
    {
    $path_count--;
    my $pp_id = $p->{ 'PS_ID' };
    my $icon  = $p->{ 'ICON'  };
    my $title = $p->{ 'TITLE' };
    
    if( $path_count <= 0 )
      {
      # current page session
      $text .= " <b>:</b>  <img class=icon-disabled src=i/$icon> $title";
      }
    else
      {
      # previous page session
      my $alink = de_html_alink( $reo, 'none', "$icon", { CLASS => 'plain', HINT => $title }, _P => $pp_id );
      $text .= " <b>&raquo;</b> $alink";
      # $text .= " $title" if $path_count <= 1;
      }  
    }

  my $pc = @$ps_path;
  my $pc_str = str_countable( $pc, "[~step]", "[~steps]" );
  $text = "[~History]: <b>$pc</b> $pc_str $text";

  return $text;
}

1;
