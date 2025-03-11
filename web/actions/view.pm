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
use Data::Tools;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Web::Utils;


sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $master_record_table = $reo->param( 'MASTER_RECORD_TABLE' );
  my $master_record_id    = $reo->param( 'MASTER_RECORD_ID'    );

  my $ui = $reo->get_user_input();

  my $rs = $reo->get_page_session(1);
  my $ps = $reo->get_page_session();

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des(); # table "Self" description

  my $table_label = $tdes->get_label();
  my $table_type  = $sdes->{ 'TYPE' };

  if( $id == 0 )
    {
    $id = $core->select_first1_field( $table, '_ID', { ORDER_BY => 'DESC' } );

    return "<#access_denied>" if $id == 0;
    }

  my ( $browser_window_title, $browser_window_hint ) = $reo->ps_path_add_by_cue( $sdes, 'VIEW' );

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );

  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };

  return "<#access_denied>" unless @fields;

  if( $ui->{ "UPLOAD_FILE" } )
    {
    my $upload = $ui->{ "UPLOAD_FILE:UPLOAD" };

    my $upload_fn = file_name_ext( $upload->{ 'filename' } );
    my $mime      = $upload->{ 'headers' }{ 'content-type' };

    my $new_id    = $core->file_save( $upload->{ 'tempname' }, $table, $upload_fn, $id, { MIME => $mime } );
    }

#  push @fields, 'USR.ACTIVE';

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

#$text .= Dumper( \%basef );

  @fields = grep { $link_field_disable ne $_ } @fields;

  my $fields = join ',', @fields, values %basef;

  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $row_data = $core->fetch( $select );
  return "<p><#no_data><p>" unless $row_data;

  $text .= de_master_record_view( $reo );

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
#  $text .= "<table class='view record' cellspacing=0 cellpadding=0>";
#  $text .= "<tr class=view-header>";
#  $text .= "<td class='view-header record-field fmt-center' colspan=2>$browser_window_title</td>";
#  $text .= "</tr>";

  
  my $row_id = $row_data->{ '_ID' };

  $text .= "<p>";
  $text .= "<div class='record-table'>";
  $text .= "<div class='view-header view-sep record-sep fmt-center'>$browser_window_title</div>";

  my $record_name     = $sdes->get_attr( qw( WEB VIEW RECORD_NAME ) );
  $record_name =~ s/\$([A-Z_0-9]+)/exists $row_data->{ $1 } ? $row_data->{ $1 } : undef/gie;
  $browser_window_title .= "| $record_name";
  $reo->ps_path_add( 'view', $browser_window_title );

#print STDERR Dumper( $row_data );

  my $user_is_root = $reo->user_has_group( 1 );

  my @backlinks_text;

  @fields = grep { /^_/ ? $user_is_root ? 1 : 0 : 1 } @fields;

  my $record_first = 1;
  for my $field ( @fields )
    {
    my $bfdes      = $bfdes{ $field };
    my $lfdes      = $lfdes{ $field };
    my $type_name  = $lfdes->{ 'TYPE' }{ 'NAME'  };
    my $type_lname = $lfdes->{ 'TYPE' }{ 'LNAME' };


    next if ! $user_is_root and $bfdes->get_attr( qw( WEB VIEW HIDE ) );

    my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

    my $label     = $bfdes->get_attr( qw( WEB VIEW LABEL ) );

#    my $label = "$blabel";
#    if( $bfdes ne $lfdes )
#      {
#      my $llabel     = $lfdes->get_attr( qw( WEB VIEW LABEL ) );
#      $label .= "/$llabel";
#      }

    my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

    my $data      = $row_data->{ $field };
    next if $bfdes->get_attr( qw( WEB VIEW HIDE_IF_EMPTY ) ) and ( ( $type_name eq 'CHAR' and $data eq '' ) or ( $type_name ne 'CHAR' and $data == 0 ) ); # FIXME: move to func

    my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
    my ( $data_fmt, $data_fmt_class );
    my $data_ctrl;
    my $field_details;
    my $no_layout_ctrls = 0;


    my $overflow  = $bfdes->get_attr( qw( WEB VIEW OVERFLOW ) );
    if( $overflow )
      {
      $data_fmt = str_html_escape( $data_fmt );
      $data_fmt = "<form><input value='$data_fmt' style='width: 96%' readonly></form>";
      }

    my $same_data_search; # FIXME: !!!
    if( $bfdes->is_linked() or $bfdes->is_widelinked() )
      {
      ( $data_fmt, $data_fmt_class )  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id, CORE => $core } );

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
            $data_fmt   = de_html_alink(      $reo, 'new', "$data_fmt",    "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'view.svg',     "[~View linked record]",              ACTION => 'view',    ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_up.svg',  "[~Upload and replace current file]", ACTION => 'file_up', ID => $data_base, TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_dn.svg',  "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );

            # FIXME: TODO: set option
            $field_details .= qq( <iframe reactor_src="?action=file_dn&table=$linked_table&id=$data_base" width="100%" height="700px"></iframe> );
            }
          else
            {
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload new file]",                 ACTION => 'file_up', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            }
          }
        else
          {
          my $enum = $ltdes->get_table_type() eq 'ENUM';
          if( $data_base > 0 )
            {
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'view.svg',      "[~View linked record]",                            ACTION => 'view', ID => $data_base, TABLE => $linked_table ) unless $enum;
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'list-same.svg', "[~View all records with the same] <b>$label</b>",  ACTION => 'grid',                   TABLE => $table, FILTER => { $base_field => $same_data_search } );
            $data_fmt   = de_html_alink( $reo, 'new', "$data_fmt",          "[~View linked record]",                            ACTION => 'view', ID => $data_base, TABLE => $linked_table ) unless $enum;
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
      my ( $backlinked_table, $backlinked_field, $backlinked_src ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );

      my $backlinked_src_data = $row_data->{ $backlinked_src };

      my $linked_table_label = $bltdes->get_label();

      my ( $backlink_insert_cue, $backlink_insert_cue_hint ) = de_web_get_cue( $bfdes, qw( WEB VIEW BACKLINK_INSERT_CUE ) );

      if( uc( $bfdes->get_attr( 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all related records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } );
        }
      else
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $backlinked_src_data, LINK_FIELD_VALUE => $backlinked_src_data, FILTER => { $backlinked_field => $backlinked_src_data } );
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'attach.svg', "[~View NOT connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $backlinked_src_data, LINK_FIELD_VALUE =>                    0, FILTER => { $backlinked_field =>                    0 } );
        }  

      if( $bltdes->allows( 'INSERT' ) )
        {
        if( $bltdes->get_table_type() eq 'FILE' )
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload and link new files]", ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 );
          }
        else
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.svg', "[~Create and connect a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $backlinked_src_data, LINK_FIELD_DISABLE => $backlinked_field, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id );
          }
        }

      if( $bltdes->allows( 'READ' ) )
        {
        my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
        $count = 'Unknown' if $count eq '';
        my $uncount = $core->count( $backlinked_table, { FILTER => { $backlinked_field => 0 } });
        my $acount  = $core->count( $backlinked_table, );

        my $count_s   = str_num_comma( $count   );
        my $uncount_s = str_num_comma( $uncount );
        
        $data_fmt = undef;
        $data_fmt .= de_html_alink( $reo, 'new', "<b class=hi>$count_s</b> [~records from] <b class=hi>$linked_table_label</b>",   "[~View all backlinked records from] <b class=hi>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } );
        $data_fmt .= de_html_alink( $reo, 'new', " ( + <b class=hi>$uncount_s</b> [~NOT connected records])",   "[~View all backlinked records from] <b class=hi>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_VALUE => 0, FILTER => { $backlinked_field => 0 } ) if $uncount > 0;

        my $detail_fields = $bfdes->get_attr( qw( WEB EDIT DETAIL_FIELDS ) );
        if( $detail_fields )
          {
          my $backlink_text = "<p>";

          $detail_fields = join ',', @{ $bltdes->get_fields_list() } if $detail_fields eq '*';

          my $bltsdes = $bltdes->get_table_des();
          my $bltable_type = $bltsdes->{ 'TYPE' };
          my ( $view_cue,   $view_cue_hint   ) = de_web_get_cue( $bltsdes, qw( WEB GRID VIEW_CUE   ) );
          my ( $update_cue, $update_cue_hint ) = de_web_get_cue( $bltsdes, qw( WEB GRID UPDATE_CUE ) );
          my ( $copy_cue,   $copy_cue_hint   ) = de_web_get_cue( $bltsdes, qw( WEB GRID COPY_CUE   ) );
          my ( $download_file_cue, $download_file_cue_hint ) = de_web_get_cue( $bltsdes, qw( WEB GRID DOWNLOAD_FILE_CUE ) );

          my $sub_de_data_grid_cb = sub
            {
            my $cbid = shift;
            my $ccid = $reo->create_uniq_id();
            my $vec_ctrl;
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "view.svg",    $view_cue_hint,          ACTION => 'view',    ID => $cbid, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, LINK_FIELD_DISABLE => $backlinked_field  );
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "edit.svg",    $update_cue_hint,        ACTION => 'edit',    ID => $cbid, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, ) if $bltdes->allows( 'UPDATE' );
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "copy.svg",    $copy_cue_hint,          ACTION => 'edit',    ID =>    -1, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, COPY_ID => $cbid, LINK_FIELD_DISABLE => $backlinked_field, "F:$backlinked_field" => $id ) if $bltdes->allows( 'INSERT' ) and ! $bltdes->{ '@' }{ 'NO_COPY' };
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', 'file_dn.svg', $download_file_cue_hint, ACTION => 'file_dn', ID => $cbid, TABLE => $backlinked_table                                                          ) if $bltable_type eq 'FILE';
            return $vec_ctrl;
            };

          my $details_limit = $bfdes->get_attr( qw( WEB VIEW DETAILS_LIMIT ) ) || 16;

          my ( $dd_grid, $dd_count ) = de_data_grid( $core, $backlinked_table, $detail_fields, { FILTER => { $backlinked_field => $id }, LIMIT => $details_limit, CLASS => 'grid view record', TITLE => "[~Related] $linked_table_label", CTRL_CB => $sub_de_data_grid_cb, SUMS => 0 } ) ;
          $field_details .= $dd_grid;

          if( uc( $bfdes->get_attr( 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
            {
            $field_details .= de_html_alink_button( $reo, 'new', "[~View all related records] ($count)",   "[~View all related records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } ) unless $count <= $dd_count;
            }
          else
            {  
            $field_details .= de_html_alink_button( $reo, 'new', " <img src=i/grid.svg> [~View all] <b>$linked_table_label</b>  ($count)",     "[~View all connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } ) unless $count <= $dd_count;
            $field_details .= de_html_alink_button( $reo, 'new', " <img src=i/attach.svg> [~View unattached] <b>$linked_table_label</b>",   "[~View all not connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => 0, FILTER => { $backlinked_field => 0 } ) if $uncount > 0;
            }
          
          if( $bltdes->allows( 'INSERT' ) )
            {
            if( $bltdes->get_table_type() eq 'FILE' )
              {
              $field_details .= de_html_alink_button( $reo, 'new', '  <img src=i/file_new.svg> [~Upload new file]', "[~Upload and link new files]", BTYPE => 'act', ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 );
              }
            else
              {
              my ( $insert_cue, $insert_cue_hint ) = de_web_get_cue( $bltdes->get_table_des(), qw( WEB GRID INSERT_CUE ) );
              $field_details .= de_html_alink_button( $reo, 'new', "(+) $insert_cue", $insert_cue_hint, BTYPE => 'act', ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id );
              }
            }  
          $no_layout_ctrls = 1;

          $backlink_text .= $field_details;
          
          push @backlinks_text, $backlink_text;
          next;
          }
        }
      else
        {
        $data_fmt = "<span class=warning>[~ACCESS DENIED]</span>";
        }  
      }
    else
      {
      ( $data_fmt, $data_fmt_class )  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id, CORE => $core } );
      }  

    if( $lpassword )
      {
      $data_fmt = "[~(hidden)]";
      }

    if( $type_name eq 'CHAR' and $type_lname eq 'LOCATION' )
      {
      $data_fmt = str_html_escape( $data_fmt );
      $data_fmt = de_html_alink_button( $reo, 'new', " <img src=i/map_location.svg> $data_fmt", "[~View map location]", ACTION => 'map_location', LL => $data );
      }

    my $divider = $bfdes->get_attr( 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='view-divider view-sep record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

    my $data_layout = $no_layout_ctrls ? $data_fmt : html_layout_2lr_flex( $data_fmt, $data_ctrl, '<==1>' );
    my $base_field_class = lc "css_view_class_$base_field";
#    $text .= "<tr class=view>";
#    $text .= "<td class='view-field record-field $base_field_class                ' >$label</td>";
#    $text .= "<td class='view-value record-value $base_field_class $data_fmt_class' >$data_layout</td>";
#    $text .= "</tr>\n";

    my $record_first_class = 'record-first' if $record_first;
    $record_first = 0;
    $text .= "<div class='record-field-value'>
                <div class='view-field record-field $record_first_class $base_field_class                ' >$label</div>
                <div class='view-value record-value $record_first_class $base_field_class $data_fmt_class' >$data_layout</div>
              </div>";

    if( $field_details )
      {
      $text .= "<div class='view-details record-details'>$field_details</div>";
#      $text .= "<tr class=view>";
#      $text .= "<td colspan=2 class='details-fields' >$field_details</td>";
#      $text .= "</tr>\n";
      #$data_layout .= $field_details;
      }
    }
  $text .= "</div>";

  my $ps_path = $ps->{ 'PS_PATH' };
  my $back_hint = @$ps_path > 1 ? ': ' . $ps_path->[ -2 ]{ 'TITLE' } : undef;
  
  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Back]", "[~Return to previous screen]$back_hint", BTYPE => 'nav' ) if $rs;
  if( $tdes->allows( 'UPDATE' ) )
    {
    my $update_cue = de_web_get_cue( $sdes, qw( WEB GRID UPDATE_CUE ) );
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$update_cue &uArr;", $update_cue, BTYPE => 'mod', ACTION => 'edit', ID => $id, TABLE => $table, LINK_FIELD_DISABLE => $link_field_disable, MASTER_RECORD_TABLE => $master_record_table, MASTER_RECORD_ID => $master_record_id );
    }

  if( $table_type ne 'FILE' and $tdes->allows( 'INSERT' ) and ! $tdes->{ '@' }{ 'NO_COPY' } )
    {
    # my $copy_cue = $sdes->get_attr( qw( WEB GRID COPY_CUE ) ) || "[~Copy this record as new]";
    my ( $copy_cue, $copy_cue_hint ) = de_web_get_cue( $sdes, qw( WEB GRID COPY_CUE ) );
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$copy_cue (+)", $copy_cue_hint, BTYPE => 'act', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    }

  if( $table_type eq 'FILE' )
    {
    my $download_cue = $sdes->get_attr( qw( WEB GRID DOWNLOAD_CUE ) ) || '[~Download file]';
    $text .= de_html_alink_button( $reo, 'new', "(&darr;) $download_cue", undef,   BTYPE => 'act', ACTION => 'file_dn',     TABLE => $table, ID => $id,                  );
  
    if( $tdes->allows( 'UPDATE' ) )
      {
      my $upload_cue = $sdes->get_attr( qw( WEB GRID UPLOAD_CUE ) ) || "[~Re-Upload file]";
      #$text .= de_html_alink_button( $reo, 'new', "(&uarr;) $upload_cue", '[~Replace current file with new one]',   BTYPE => 'act', ACTION => 'file_up', TABLE => $table, ID => $id, );

      my $up_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
      $text .= $up_form->begin( NAME => "form_up_$table" );
      $text .= $up_form->file_upload( NAME     => "UPLOAD_FILE", ID => "upload_file_input", ARGS => qq{ onChange="this.form.submit();" style="display: none" } );
      $text .= $up_form->button( NAME => "UPLOAD_FILE_OK", VALUE => $upload_cue, CLASS => "button mod-button", ARGS => qq{ onClick='document.getElementById("upload_file_input").click();return false;'} );
      $text .= $up_form->end();
      }
    }
  
  for my $do ( @{ $tdes->get_category_list_by_oper( 'DO', 'EXECUTE' ) }  )
    {
    my $dodes   = $tdes->get_category_des( 'DO', $do );
    next if $dodes->get_attr( qw( WEB VIEW HIDE  ) );
    my $dolabel = $dodes->get_attr( qw( WEB VIEW LABEL ) );
    $text .= de_html_alink_button( $reo, 'new',  "$dolabel &sect;", "$dolabel", ACTION => 'do', DO => $do, ID => $id, TABLE => $table );
    }

  for my $act ( @{ $tdes->get_category_list_by_oper( 'ACTION', 'EXECUTE' ) }  )
    {
    my $actdes   = $tdes->get_category_des( 'ACTION', $act );
    my $label  = $actdes->{ 'LABEL'  };
    my $target = $actdes->{ 'TARGET' } || $actdes->{ 'NAME' };
    my $icon   = lc( $actdes->{ 'ICON'   } );
    $icon = $icon =~ /^[a-z_0-9]+$/ ? "action_$icon.svg" : "action_generic.svg";
    $text .= de_html_alink_button( $reo, 'new', "<img src=i/$icon> $label", $label, ACTION => $target, ID => $id, TABLE => $table );
    }


  $text .= de_html_alink_button( $reo, 'new', 'Actions Log', "View modifications made by users",  BTYPE => '', ACTION => 'alog_view', TABLE => $table, OID => $id );

  $text .= "<div class='record-table-envelope'>";
  $text .= join '', @backlinks_text;
  $text .= "</div>";

  $text .= "<#view_bottom_$table>";

  return $text;
}

1;
