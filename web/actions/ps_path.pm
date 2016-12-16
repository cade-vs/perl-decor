package decor::actions::ps_path;
use strict;
use Data::Dumper;
use Data::Tools;
use Decor::Web::HTML::Utils;
use Web::Reactor::HTML::Utils;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $ps    = $reo->get_page_session();                                                                                            
  my $ps_id = $reo->get_page_session_id();

  my $ps_path = $ps->{ 'PS_PATH' } || [];
  
  return undef unless @$ps_path > 0;
  
  my $text;
  
  for my $p ( @$ps_path )
    {
    my $pp_id = $p->{ 'PS_ID' };
    my $icon  = $p->{ 'ICON'  };
    my $title = $p->{ 'TITLE' };
    
    if( $pp_id eq $ps_id )
      {
      # current page session
      $text .= " <b>&raquo;</b> <img class=icon-disabled src=i/$icon> $title";
      }
    else
      {
      # previous page session
      my $alink = de_html_alink( $reo, 'none', "$icon", $title, _P => $pp_id );
      $text .= " <b>&raquo;</b> $alink";
      }  
    }

  my $pc = @$ps_path;
  my $pc_str = str_countable( $pc, "step", "steps" );
  $text = "<tr class=ps-path><td class=ps-path>History: <b>$pc</b> $pc_str $text</td></tr>";

  return $text;
}

1;
