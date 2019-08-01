##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::do;
use strict;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );
  my $ids    = $reo->param( 'IDS'   );
  my $do     = $reo->param( 'DO'    );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  $reo->ps_path_add( 'do', qq( Do work on "<b>$table_label</b>" ) );

  my $dodes   = $tdes->get_category_des( 'DO', $do );
  
  return "<#access_denied>" unless $dodes->allows( 'EXECUTE' );
  
  my @ids;
  push @ids, $id   if $id   > 0;
  push @ids, @$ids if $ids and @$ids > 0;

  my $html_file;
  if( @ids > 0 )
    {
    for my $id ( @ids )
      {
      $core->do( $table, $do, {}, $id );
      
      my ( $file_body, $file_mime ) = $core->get_return_file_body_mime();

# FIXME: URGENT: ONLY FOR TEXT MIMEs
use Encode;
$file_body = Encode::decode_utf8( $file_body );
      
      if( $file_mime ne '' )
        {
        if( $file_mime eq 'text/plain' )
          {
          $html_file .= "<xmp>$file_body</xmp>";
          }
        elsif( $file_mime eq 'text/html' )
          {
          $html_file .= $file_body;
          }
        else
          {
          $html_file .= "*** UNSUPPORTED DATA TYPE ***";
          }  
        }  
      }
    }
  else
    {
$text .= "[@ids]";

    $core->do( $table, $do );
    my ( $file_body, $file_mime ) = $core->get_return_file_body_mime();
# FIXME: URGENT: ONLY FOR TEXT MIMEs
use Encode;
$file_body = Encode::decode_utf8( $file_body );
    $html_file .= $file_body;
    }  
  
  $html_file ||= "*** DONE ***"; # FIXME: must be more meaningful text :)
  $text .= $html_file;
  $reo->html_content_set( 'for_printer' => $html_file );

  $text .= "<p>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Continue]", "[~Return and continue on previous screen]" );
  $text .= "<a class=button href='javascript:window.print()'><~Print this text></a>" if $dodes->get_attr( 'WEB', 'PRINT' );
  
  return $text;
}

1;
