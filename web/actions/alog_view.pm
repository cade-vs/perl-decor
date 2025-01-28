##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::alog_view;
use strict;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Shared::Types;
use Data::Tools;
use Data::Dumper;

sub main
{
  my $reo = shift;

  my $core = $reo->de_connect();

  my $text;

  my $table  = uc $reo->param( 'TABLE' );
  my $oid    = $reo->param( 'OID'    );

  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des(); # table "Self" description

  my $select = $core->select( 'DE_ALOG', 'USR,USR.USERNAME,SESS,SESS.CTIME,OPER,CTIME,DATA', { FILTER => { TAB => $table, OID => $oid }, ORDER_BY => '._ID ASC' } );

  my $c = 1;
  my $last_data = {};
  while( my $row_data = $core->fetch( $select ) )
    {
    my $user       = $row_data->{ 'USR' };
    my $username   = $row_data->{ 'USR.USERNAME' };
    my $sess       = $row_data->{ 'SESS' };
    my $sess_ctime = type_format( $row_data->{ 'SESS.CTIME' }, 'UTIME' );
    my $oper       = $row_data->{ 'OPER' };
    my $ctime      = type_format( $row_data->{ 'CTIME' }, 'UTIME' );
    my $data       = ref_thaw( $row_data->{ 'DATA' } );
    
    $text .= "<p><div class='record-table'>";
    $text .= "<div class='view-header view-sep record-sep fmt-center'>(change $c) <b>$username</b> logged at <b>$sess_ctime</b> did <b>$oper</b> at <b>$ctime</b></div>";
    $text .= "<div class='record-field-value'>
                <div class='view-field record-field' >Field changed</div>
                <div class='view-field record-field' >from</div>
                <div class='view-value record-value' >to</div>
              </div>";
    
    my @f = list_uniq( keys %$data, keys %$last_data );
    for my $f ( @f )
      {
      my $fr = $last_data->{ $f };
      my $to =      $data->{ $f };

      my $fdes = $tdes->get_field_des( $f );
      
      $fr = de_web_format_field( $fr, $fdes, 'VIEW', { ID => $oid, CORE => $core } );
      $to = de_web_format_field( $to, $fdes, 'VIEW', { ID => $oid, CORE => $core } );

      next if $fr eq $to;

      my $label = $fdes->get_attr( qw( WEB VIEW LABEL ) );
      
      $text .= "<div class='record-field-value'>
                  <div class='view-field record-field' >$label</div>
                  <div class='view-field record-field' >$fr</div>
                  <div class='view-value record-value' >$to</div>
                </div>";
      }

    $text .= "</div>";
    
    $last_data = $data;
    $c++;
    }

  $text .= "<p>";
  $text .= de_html_alink_button( $reo, 'back', 'Back', "Return to the previous page" );

  return $text;
}

1;
;
