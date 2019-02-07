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
use Data::Dumper;
use Exception::Sink;

use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $text;

  # FIXME: invalidate session first!!!
  my $ps = $reo->get_page_session();

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data> $table|$id" unless $table and $id;

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );


  my $fields_ar        = $ps->{ 'FIELDS_WRITE_AR'  };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  return "<#access_denied>" unless @$fields_ar;

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;

  my %write_data = map { $_ => $row_data->{ $_ } } @$fields_ar;

  my $res;
  if( $edit_mode_insert )
    {
    my $opt = {};
    
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
    $res = $core->update( $table, \%write_data, { ID => $id } );
    }  

#print STDERR Dumper( $res, $row_data, \%write_data );
#print STDERR Dumper( $res, $core );

  if( $res )
    {
    # no error, return to caller

    my $return_data_from = $reo->param( 'RETURN_DATA_FROM' );
    my $return_data_to   = $reo->param( 'RETURN_DATA_TO'   );

    my @return_args;
    
    if( $return_data_from and $return_data_to )
      {
      $row_data->{ '_ID' } = $id;
      push @return_args, ( "F:$return_data_to" => $row_data->{ $return_data_from } );
      }
 
    my ( $file_body, $file_mime ) = $core->get_return_file_body_mime();

    # FIXME: URGENT: ONLY FOR TEXT MIMEs
    use Encode;
    $file_body = Encode::decode_utf8( $file_body );
    
    if( $file_mime eq '' )
      {
      # no return file, go back now
      $reo->forward_back( @return_args );
      }
    else  
      {
      my $html_file;
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
      $text .= "<p>";
      $text .= $html_file;
      $text .= "<p><br>";
      $text .= de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "[~Operation done, continue...]"       );
      }  
    return $text;
    }

  my $res_msg = $res ? "OK" : "Error";

  my $text .= "<br>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>[~Field]</td>";
  $text .= "<td class='view-header fmt-left' >[~Value]</td>";
  $text .= "</tr>";

  $text .= "<tr class=view>";
  $text .= "<td class='view-field' >[~Operation result]</td>";
  $text .= "<td class='view-value' >$res_msg</td>";
  $text .= "</tr>";

  $text .= "</table>";

#  my $ok_hint = $edit_mode_insert ? "Confirm new record insert" : "Confirm record update";
  
  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'here', "&lArr; [~Back]",     "[~Back to data edit screen]", ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "[~Operation done, continue...]"       );
#  $text .= de_html_alink_button( $reo, 'new',  "OK",     $ok_hint,                   ACTION => 'commit' );

  return $text;
}

1;
