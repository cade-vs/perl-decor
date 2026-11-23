##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::commit;
use strict;
use Decor::Shared::Describe;
use Data::Dumper;
use Exception::Sink;
use Encode; # moved from the sub body

use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML; # elements, attributes, escaping, no longer exported by HTML::Utils
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $text;

  # the page session is invalidated below, before the write
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data>" unless $table and $id;

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = des_table_des( $tdes ); # table "Self" description

  my $fields_ar        = $ps->{ 'FIELDS_WRITE_AR'  };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  return "<#access_denied>" unless @$fields_ar;

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;

  return "<#invalid_page_session>" if $ps->{ ':INVALID' };
  $ps->{ ':INVALID' } = scalar localtime();
  $reo->save();

  my %write_data = map { $_ => $row_data->{ $_ } } @$fields_ar;

  my $res;
  my $opt = {};
  $opt->{ 'EDIT_SID' } = $ps->{ 'EDIT_SID' } if $ps->{ 'EDIT_SID' };

  if( $edit_mode_insert )
    {
    my $lt_table = $reo->param( 'LINK_TO_TABLE' );
    my $lt_field = $reo->param( 'LINK_TO_FIELD' );
    my $lt_id    = $reo->param( 'LINK_TO_ID'    );

    if( $lt_table and $lt_field and $lt_id )
      {
      $opt->{ 'LINK_TO_TABLE' } = $lt_table;
      $opt->{ 'LINK_TO_FIELD' } = $lt_field;
      $opt->{ 'LINK_TO_ID'    } = $lt_id;
      }

    $res = $core->insert( $table, \%write_data, $id, $opt );
    }
  else
    {
    $opt->{ 'ID' } = $id;

    $res = $core->update( $table, \%write_data, $opt );
    }

#print STDERR Dumper( $res, $row_data, \%write_data );
#print STDERR Dumper( $res, $core );

  if( $res )
    {
    # no error, return to caller unless DO is specified to confirm or provide more information!!!!!!!!!!!!!!!!!

    my $return_data_from = $reo->param( 'RETURN_DATA_FROM' );
    my $return_data_to   = $reo->param( 'RETURN_DATA_TO'   );

    my @return_args;

    if( $return_data_from and $return_data_to )
      {
      $row_data->{ '_ID' } = $id;
      push @return_args, ( "F:$return_data_to" => $row_data->{ $return_data_from } );
      }

    # the return data goes through the DO, its Continue button returns it to the caller
    # FIXME: needs review: forward() does not return, with a POST_INSERT/POST_UPDATE DO the return file and VIEW_ON_INSERT below are skipped
    $reo->forward( '_R' => $rs->{ ':ID' }, ACTION => 'DO', TABLE => $table, ID => $id, DO => 'POST_INSERT', RETURN_ARGS => { @return_args } ) if   $edit_mode_insert and des_exists_category( 'DO', $tdes, 'POST_INSERT' );
    $reo->forward( '_R' => $rs->{ ':ID' }, ACTION => 'DO', TABLE => $table, ID => $id, DO => 'POST_UPDATE', RETURN_ARGS => { @return_args } ) if ! $edit_mode_insert and des_exists_category( 'DO', $tdes, 'POST_UPDATE' );

    my ( $file_body, $file_mime ) = $core->get_return_file_body_mime();

    $file_body = Encode::decode_utf8( $file_body ) if $file_mime eq 'text/plain' or $file_mime eq 'text/html'; # only text bodies are decoded

    if( $file_mime eq '' )
      {
      # no return, text, forward to VIEW screen as requested
      return $reo->forward( '_R' => $rs->{ ':ID' }, ACTION => 'VIEW', TABLE => $table, ID => $id ) if $edit_mode_insert and des_attr( $sdes, qw( WEB VIEW_ON_INSERT ) );

      # no return file, go back now
      return $reo->forward_back( @return_args );
      }
    else
      {
      my $html_file;
      if( $file_mime eq 'text/plain' )
        {
        $html_file .= html_element_e( 'pre', $file_body );
        }
      elsif( $file_mime eq 'text/html' )
        {
        $html_file .= $file_body;
        }
      else
        {
        $html_file .= "*** [~Unsupported data type] ***"; # translated
        }
      $reo->html_hold_set( 'for_printer' => $html_file );
      $text .= "<p>";
      $text .= $html_file;
      $text .= "<p><br>";
      $text .= de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "[~Operation done, continue...]"       );
      }
    return $text;
    }
  else
    {
    # error occurred, allow page reload (repeat action)
    delete $ps->{ ':INVALID' };
    }

  # only the error case gets here, success returns above

  $text .= "<p>";
  my $status_ref = $core->status_ref();
#-  my $ref_text   = $status_ref ne '' ? '[~Please, report this error reference to the administrators:] ' . html_escape( $status_ref ) : ''; # no reference (e.g. connection error), no dangling text # cc20261110-4
  my $ref_text   = $status_ref ne '' ? '[~Please, report this error reference to the administrators:] ' . html_text( $status_ref ) : ''; # no reference (e.g. connection error), no dangling text # cc20261110-4
  $text .= "<div class=error-text><h3>[~Operation result:] [~Error!]</h3>$ref_text</div>"; # translated, no <p> inside <h3>
  $text .= "<p>";

#  my $ok_hint = $edit_mode_insert ? "Confirm new record insert" : "Confirm record update";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'here', "[~Edit] &uArr;",   { HINT => "[~Back to data edit screen]", BTYPE => 'mod' }, ACTION => 'edit'   ); # BTYPE in the options, not a link arg
  $text .= de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "[~Operation done, continue...]"       );
#  $text .= de_html_alink_button( $reo, 'new',  "OK",     $ok_hint,                   ACTION => 'commit' );

  return $text;
}

1;
