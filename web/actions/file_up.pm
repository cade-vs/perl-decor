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

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $text;

  if( $file_upload )
    {
#print STDERR Dumper( '******************FILE UP', ref( $file_fh ), $file_upload );

    my $new_id = $core->file_save_fh( $file_fh, $table, $file_upload, $id , { DES => $file_des } );

###

    $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Continue]", "Return and continue on previous screen" );
    }
  else
    {
    $text = "<#file_upload_form>";
    $text .= "<p>";
    $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Continue]", "Return and continue on previous screen" );
    }  


  return $text;
}

1;
