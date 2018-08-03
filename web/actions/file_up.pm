##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::file_up;
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
  
  my $ui = $reo->get_user_input();

  my $file_fh     = $ui->{ 'FILE_UPLOAD:FH' };
  my $file_upload = $ui->{ 'FILE_UPLOAD' };
  my $file_des    = $ui->{ 'FILE_DES' };

  my $lt_table = $reo->param( 'LINK_TO_TABLE' );
  my $lt_field = $reo->param( 'LINK_TO_FIELD' );
  my $lt_id    = $reo->param( 'LINK_TO_ID'    );

  my $rt_field = $reo->param( 'RETURN_DATA_TO' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $text;

        print STDERR "+++++++++++++++++++++++++++ UPLOAD\n";

  if( $file_upload )
    {
#print STDERR Dumper( '******************FILE UP', ref( $file_fh ), $file_upload );

    my $mime = $ui->{ 'FILE_UPLOAD:UPLOAD_INFO' }{ 'Content-Type' };

    $file_upload =~ s/^.*?\/([^\/]+)$/$1/;

#print STDERR Dumper( "******************FILE UP: pre save\n" );
    my $new_id = $core->file_save_fh( $file_fh, $table, $file_upload, $id, { DES => $file_des, MIME => $mime } );
#print STDERR Dumper( "******************FILE UP: post save, new id $new_id\n" );

    if( $new_id > 0 )
      {
      if( $lt_table and $lt_field and $lt_id > 0 )
        {
        $core->update( $lt_table, { $lt_field => $new_id }, { FILTER => { _ID => $lt_id } } );
        # FIXME: check and report error
        }

      my %ret_opt;
      
      $ret_opt{ "F:$rt_field" } = $new_id if $rt_field;

      if( $reo->param( 'EMBEDDED' ) )
        {
        print STDERR de_html_alink( $reo, 'new', "$file_upload", "[~Download current file]", ACTION => 'file_dn', ID => $new_id, TABLE => $table );
        print STDERR "+++++++++++++++++++++++++++ RET EMBED\n";
        return de_html_alink( $reo, 'new', "$file_upload", "[~Download current file]", ACTION => 'file_dn', ID => $new_id, TABLE => $table );
        }

      return $reo->forward_back( %ret_opt );
      
#      $text .= "<p>";
#      $text .= "<#upload_ok>";
#      $text .= "<p>";
#      $text .= "<a class=button reactor_back_href=?>&lArr; [~Continue]</a>";
      }
    else
      {
      if( $reo->param( 'EMBEDDED' ) )
        {
        print STDERR "+++++++++++++++++++++++++++ RET EMBED ERROR\n";
        return "<~Error>";
        }
      $text .= "<p>";
      $text .= "<#e_upload>";
      $text .= "<p>";
      $text .= "<#file_upload_form>";
      }  

    }
  else
    {
    $text .= "<#file_upload_form>";
    }  

  return $text;
}

1;
