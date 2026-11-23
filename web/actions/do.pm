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
use Decor::Shared::Describe;
use Decor::Web::Utils;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML; # elements, attributes, escaping, no longer exported by HTML::Utils
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;
use MIME::Base64;
use Encode;

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );
  my $ids    = $reo->param( 'IDS'   );
  my $do     = $reo->param( 'DO'    );
  my $return_args = $reo->param( 'RETURN_ARGS' ) || {}; # from commit POST_INSERT/POST_UPDATE, e.g. the new record ID for the caller form

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = des_table_label( $tdes );

  my $dodes   = des_category_des( $tdes, 'DO', $do );
  
  return "<#access_denied>" unless de_web_profile()->allows( $dodes, 'EXECUTE' );
  $reo->ps_path_add( 'do', qq( [~Do work on] "<b>$table_label</b>" ) );
  
  my @ids;
  push @ids, $id   if $id   > 0;
  push @ids, @$ids if $ids and @$ids > 0;

  my $html_file;
  # one DO run per record, or one run without a record, all results are shown the same way
  for my $do_id ( @ids > 0 ? @ids : ( undef ) )
    {
    if( ! $core->do( $table, $do, {}, $do_id ) )
      {
      my $status_ref = $core->status_ref();
#-      my $ref_text   = $status_ref ne '' ? ' [~Please, report this error reference to the administrators:] ' . html_escape( $status_ref ) : ''; # no reference (e.g. connection error), no dangling text # cc20261110-4
      my $ref_text   = $status_ref ne '' ? ' [~Please, report this error reference to the administrators:] ' . html_text( $status_ref ) : ''; # no reference (e.g. connection error), no dangling text # cc20261110-4
      $html_file .= "<div class=error-text>[~Error!]$ref_text</div>";
      next;
      }

    my ( $file_body, $file_mime ) = $core->get_return_file_body_mime();
    next if $file_mime eq '';

    $file_body = Encode::decode_utf8( $file_body ) if $file_mime eq 'text/plain' or $file_mime eq 'text/html'; # only text bodies are decoded

    if( $file_mime eq 'text/plain' )
      {
      $html_file .= html_element_e( 'pre', $file_body );
      }
    elsif( $file_mime eq 'text/html' )
      {
      $html_file .= $file_body;
      }
    elsif( $file_mime eq 'application/pdf' )
      {
      my $base64data = encode_base64( $file_body, '' ); # one line, it is also used in the download link href
#-      my $download   = html_element( 'a', '[~Download the PDF file]', href => "data:application/pdf;base64,$base64data", download => 'document.pdf' ); # the same pdf data, no placeholder file # cc20261116-1
      # by hand, as the <object> below: html_attrs() blanks data: urls in href (only data:image in src/poster), # cc20261116-1
      # this one is built here from a fixed mime type and base64 text (A-Z a-z 0-9 + / =), nothing to escape # cc20261116-1
      my $download   = qq[<a href="data:application/pdf;base64,$base64data" download="document.pdf">[~Download the PDF file]</a>]; # cc20261116-1
      $text .= qq[<object data="data:application/pdf;base64,$base64data" type="application/pdf" width="80%" height="780px"><p>[~Unable to display the PDF file here.] $download</p></object>];
      }
    else
      {
      $html_file .= "*** [~Unsupported data type] ***";
      }
    }

  $html_file = "*** [~Done] ***" if $html_file eq '' and $text eq ''; # nothing returned
  if( $html_file ne '' )
    {
    $text .= "<div class=report-text>$html_file</div>";
    $reo->html_hold_set( 'for_printer' => $html_file );
    }
  
  $text .= "<p>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Continue]", "[~Return and continue on previous screen]", %$return_args ); # the record is written even if the DO failed, so the data is always returned
  $text .= html_element( 'a', '[~Print this text]', class => 'button', href => '#', onclick => 'window.print(); return false;' ) if des_attr( $dodes, 'WEB', 'PRINT' );
  
  return $text;
}

1;
