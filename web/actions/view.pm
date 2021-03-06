##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::view;
use strict;

use Data::Dumper;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Web::Utils;


sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $ps = $reo->get_page_session();

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des(); # table "Self" description

  my $table_label = $tdes->get_label();
  my $table_type  = $sdes->{ 'TYPE' };

  my $browser_window_title = qq( [~View a record from] "<b>$table_label</b>" );
  $reo->ps_path_add( 'view', $browser_window_title );

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );

  my @fields = grep { $link_field_disable ne $_ } @{ $tdes->get_fields_list_by_oper( 'READ' ) };

  return "<#access_denied>" unless @fields;

#  push @fields, 'USR.ACTIVE';

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

#$text .= Dumper( \%basef );

  my $fields = join ',', @fields, values %basef;

  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $text .= "<br>";

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
  $text .= "<table class='view record' cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header record-field fmt-center' colspan=2>$browser_window_title</td>";
  $text .= "</tr>";

  my $row_data = $core->fetch( $select );
  if( ! $row_data )
    {
    return "<p><#no_data><p>" . de_html_alink_button( $reo, 'back', "[~Back]", "[~Return to previous screen]" );
    }
  my $row_id = $row_data->{ '_ID' };

  my $record_name     = $sdes->get_attr( qw( WEB VIEW RECORD_NAME ) );
  $record_name =~ s/\$([A-Z_0-9]+)/exists $row_data->{ $1 } ? $row_data->{ $1 } : undef/gie;
  $browser_window_title .= "| $record_name";
  $reo->ps_path_add( 'view', $browser_window_title );

#print STDERR Dumper( $row_data );

  @fields = grep { /^_/ ? $reo->user_has_group( 1 ) ? 1 : 0 : 1 } @fields;

  for my $field ( @fields )
    {
    my $bfdes      = $bfdes{ $field };
    my $lfdes      = $lfdes{ $field };
    my $type_name  = $lfdes->{ 'TYPE' }{ 'NAME'  };
    my $type_lname = $lfdes->{ 'TYPE' }{ 'LNAME' };
    my $blabel     = $bfdes->get_attr( qw( WEB VIEW LABEL ) );

    my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

    my $label = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB VIEW LABEL ) );
      $label .= "/$llabel";
      }

    my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

    my $data      = $row_data->{ $field };
    my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
    my $data_fmt  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id } );
    my $data_ctrl;
    my $field_details;
    my $no_layout_ctrls = 0;

    next if $bfdes->get_attr( qw( WEB VIEW HIDE_IF_EMPTY ) ) and $data eq ''; # TODO: FIXME: by type? eq '', == 0, etc.

    my $overflow  = $bfdes->get_attr( qw( WEB VIEW OVERFLOW ) );
    if( $overflow )
      {
      $data_fmt = html_escape( $data_fmt );
      $data_fmt = "<form><input value='$data_fmt' style='width: 96%' readonly></form>";
      }

    my $same_data_search; # FIXME: !!!
    if( $bfdes->is_linked() or $bfdes->is_widelinked() )
      {
      my ( $linked_table, $linked_field );
      if( $bfdes->is_widelinked() ) 
        {
        $same_data_search = $data; # FIXME: !!!
        ( $linked_table, $data_base, $linked_field ) = type_widelink_parse2( $data );

        my $ltdes = $core->describe( $linked_table );
        if( $ltdes )
          {
          my $linked_table_label = $ltdes->get_label();
          if( $linked_field )
            {
            $data_fmt = $core->read_field( $linked_table, $linked_field, $data_base );
            my $lfdes = $ltdes->get_field_des( $linked_field );
            $data_fmt  = de_web_format_field( $data_fmt, $lfdes, 'VIEW', { ID => $data_base } );
            }
          else
            {
            $data_fmt = "[~Linked to a record from:] $linked_table_label";
            }  
          } # ltdes  
        }
      else
        {
        $same_data_search = $data_base; # FIXME: !!!
        ( $linked_table, $linked_field ) = $bfdes->link_details();
        }  

      my $ltdes = $core->describe( $linked_table );
      $data_fmt =~ s/\./&#46;/g;

      if( $ltdes )
      {
      if( $ltdes->get_table_type() eq 'FILE' )
        {
        if( $data_base > 0 )
          {
          # my $cue_dn_file = de_web_get_cue( qw( ) );
          $data_fmt   = de_html_alink( $reo, 'new', "$data_fmt",    "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'view.svg',     "[~View linked record]",              ACTION => 'view',    ID => $data_base, TABLE => $linked_table );
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_up.svg',  "[~Upload and replace current file]", ACTION => 'file_up', ID => $data_base, TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_dn.svg',  "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
          }
        else
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload new file]",                 ACTION => 'file_up', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
          }
        }
      else
        {
        if( $data_base > 0 )
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'view.svg',   "[~View linked record]",                                                        ACTION => 'view', ID => $data_base, TABLE => $linked_table );
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all records from] <b>$table_label</b>, [~linked to] <b>$data_fmt</b>",  ACTION => 'grid',                   TABLE => $table, FILTER => { $base_field => $same_data_search } );
          $data_fmt   = de_html_alink( $reo, 'new', "$data_fmt",    "[~View linked record]",                                                        ACTION => 'view', ID => $data_base, TABLE => $linked_table );
          }
        else
          {
          $data_fmt = '&empty;';
          }  
        
        if( $bfdes->is_linked() and $ltdes->allows( 'INSERT' ) and $tdes->allows( 'UPDATE' ) and $bfdes->allows( 'UPDATE' ) )
          {
          # FIXME: check for record access too!
          my $insert_cue = $bfdes->get_attr( qw( WEB VIEW LINK_INSERT_CUE ) ) || "[~Insert and link a new record]";
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.svg', $insert_cue, ACTION => 'edit', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
          }
        }  
        } # if $ltdes
        else
        {
        $data_fmt = "[~(n/a)]";
        }
      }
    elsif( $bfdes->is_backlinked() )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );
      my $linked_table_label = $bltdes->get_label();

      my ( $backlink_insert_cue, $backlink_insert_cue_hint ) = de_web_get_cue( $bfdes, qw( WEB VIEW BACKLINK_INSERT_CUE ) );

      if( uc( $bfdes->get_attr( 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all related records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } );
        }
      else
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } );
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'attach.svg', "[~View NOT connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE =>   0, FILTER => { $backlinked_field =>   0 } );
        }  

      if( $bltdes->allows( 'INSERT' ) )
        {
        if( $bltdes->get_table_type() eq 'FILE' )
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload and link new files]", ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 );
          }
        else
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.svg', "[~Create and connect a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field );
          }
        }

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
      $count = 'Unknown' if $count eq '';
      my $uncount = $core->count( $backlinked_table, { FILTER => { $backlinked_field => 0 } });
      my $acount  = $core->count( $backlinked_table, );

      $data_fmt = undef;
      $data_fmt .= de_html_alink( $reo, 'new', "<b class=hi>$count</b> [~records from] <b class=hi>$linked_table_label</b>",   "[~View all backlinked records from] <b class=hi>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } );
      $data_fmt .= de_html_alink( $reo, 'new', " ( + <b class=hi>$uncount</b> [~NOT connected records])",   "[~View all backlinked records from] <b class=hi>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_VALUE => 0, FILTER => { $backlinked_field => 0 } ) if $uncount > 0;

      my $details_fields = $bfdes->get_attr( qw( WEB EDIT DETAILS_FIELDS ) );
      if( $details_fields and $count > 0 )
        {
        my $details_limit = $bfdes->get_attr( qw( WEB EDIT DETAILS_LIMIT ) ) || 16;
        $field_details .= de_data_grid( $core, $backlinked_table, $details_fields, { FILTER => { $backlinked_field => $id }, LIMIT => $details_limit } ) ;

        if( uc( $bfdes->get_attr( 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
          {
          $field_details .= de_html_alink_button( $reo, 'new', '[~View all related records]',   "[~View all related records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } );
          }
        else
          {  
          $field_details .= de_html_alink_button( $reo, 'new', ' <img src=i/grid.svg> [~View attached records]',     "[~View all connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } ) unless $count == $acount;
          $field_details .= de_html_alink_button( $reo, 'new', ' <img src=i/attach.svg> [~View unattached records]',   "[~View all not connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => 0, FILTER => { $backlinked_field => 0 } ) if $uncount > 0;
          }
        
        if( $bltdes->get_table_type() eq 'FILE' )
          {
          $field_details .= de_html_alink_button( $reo, 'new', '  <img src=i/file_new.svg> [~Upload new file]', "[~Upload and link new files]", BTYPE => 'act', ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 );
          }
        else
          {
          $field_details .= de_html_alink_button( $reo, 'new', '  <img src=i/insert.svg> [~Create new record]', "[~Create and connect a new record into] <b>$linked_table_label</b>", BTYPE => 'act', ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field );
          }
        $no_layout_ctrls = 1;
        }
      }

    if( $lpassword )
      {
      $data_fmt = "[~(hidden)]";
      }

    if( $type_name eq 'CHAR' and $type_lname eq 'LOCATION' )
      {
      $data_fmt = de_html_alink_button( $reo, 'new', " <img src=i/map_location.svg> $data_fmt", "[~View map location]", ACTION => 'map_location', LL => $data );
      }

    my $data_layout = $no_layout_ctrls ? $data_fmt : html_layout_2lr( $data_fmt, $data_ctrl, '<==1>' );
    my $base_field_class = lc "css_view_class_$base_field";
    $text .= "<tr class=view>";
    $text .= "<td class='view-field record-field $base_field_class' >$label</td>";
    $text .= "<td class='view-value record-value $base_field_class' >$data_layout</td>";
    $text .= "</tr>\n";
    if( $field_details )
      {
      $text .= "<tr class=view>";
      $text .= "<td colspan=2 class='details-fields' >$field_details</td>";
      $text .= "</tr>\n";
      #$data_layout .= $field_details;
      }
    }
  $text .= "</table>";

  my $ps_path = $ps->{ 'PS_PATH' };
  my $back_hint = @$ps_path > 1 ? ': ' . $ps_path->[ -2 ]{ 'TITLE' } : undef;
  
  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Back]", "[~Return to previous screen]$back_hint", BTYPE => 'nav' );
  if( $tdes->allows( 'UPDATE' ) )
    {
    my $update_cue = $sdes->get_attr( qw( WEB GRID UPDATE_CUE ) ) || "[~Edit this record]";
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$update_cue &uArr;", $update_cue, BTYPE => 'mod', ACTION => 'edit', ID => $id, TABLE => $table, LINK_FIELD_DISABLE => $link_field_disable );
    }

  if( $tdes->allows( 'INSERT' ) )
    {
    # my $copy_cue = $sdes->get_attr( qw( WEB GRID COPY_CUE ) ) || "[~Copy this record as new]";
    my ( $copy_cue, $copy_cue_hint ) = de_web_get_cue( $sdes, qw( WEB GRID COPY_CUE ) );
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$copy_cue &uArr;", $copy_cue_hint, BTYPE => 'act', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    }

  if( $table_type eq 'FILE' )
    {
    my $download_cue = $sdes->get_attr( qw( WEB GRID DOWNLOAD_CUE ) ) || "[~Download this file]";
    $text .= de_html_alink_button( $reo, 'new', "(&darr;) $download_cue", '[~Download this file]',   BTYPE => 'act', ACTION => 'file_dn',     TABLE => $table, ID => $id,                  );
  
    my $upload_cue = $sdes->get_attr( qw( WEB GRID UPLOAD_CUE ) ) || "[~Replace current file content]";
    $text .= de_html_alink_button( $reo, 'new', "(&uarr;) $upload_cue", '[~Replace current file content]',   BTYPE => 'act', ACTION => 'file_up',     TABLE => $table, ID => $id,                  ) if $tdes->allows( 'INSERT' ) and $table_type eq 'FILE';
    }
  
  for my $do ( @{ $tdes->get_category_list_by_oper( 'READ', 'DO' ) }  )
    {
    my $dodes   = $tdes->get_category_des( 'DO', $do );
    next unless $dodes->allows( 'EXECUTE' );
    next if  $dodes->get_attr( qw( WEB GRID HIDE  ) );
    my $dolabel = $dodes->get_attr( qw( WEB VIEW LABEL ) );
    $text .= de_html_alink_button( $reo, 'new',  "$dolabel &sect;", "$dolabel", ACTION => 'do', DO => $do, ID => $id, TABLE => $table );
    }

  return $text;
}

1;
