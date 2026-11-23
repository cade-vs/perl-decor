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
use Decor::Shared::Describe;

use Data::Dumper;
use Data::Tools;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML; # elements, attributes, escaping, no longer exported by HTML::Utils
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
  my $sdes = des_table_des( $tdes ); # table "Self" description

  my $table_label = des_table_label( $tdes );
  my $table_type  = des_table_type( $tdes );

  if( $id == 0 )
    {
    $id = $core->select_first1_field( $table, '_ID', { ORDER_BY => 'DESC' } );

    return "<#access_denied>" if $id == 0;
    }

  my ( $browser_window_title ) = $reo->ps_path_add_by_cue( $sdes, 'VIEW' ); # the hint is not used

  my $link_field_disable = uc $reo->param( 'LINK_FIELD_DISABLE' ); # field names are upper case, as in grid.pm

  my @fields = @{ des_fields_list_by_oper( $tdes, 'READ', de_web_profile() ) };

  return "<#access_denied>" unless @fields;

#-  if( $ui->{ "UPLOAD_FILE" } ) # cc20261109-6
  my $upload = ( $reo->get_user_uploads()->{ "UPLOAD_FILE" } || [] )->[0]; # Plack::Request::Upload, the onChange submit sends only the file input # cc20261109-6
  if( $upload and $upload->filename ne '' and $upload->size > 0 ) # cc20261109-6
    {
#-    my $upload = $ui->{ "UPLOAD_FILE:UPLOAD" }; # cc20261109-6

#-    my $upload_fn = file_name_ext( $upload->{ 'filename' } ); # cc20261109-6
#-    my $mime      = $upload->{ 'headers' }{ 'content-type' }; # cc20261109-6
    my $upload_fn = file_name_ext( $upload->filename ); # cc20261109-6
    my $mime      = $upload->content_type; # cc20261109-6

#-    my $new_id    = $core->file_save( $upload->{ 'tempname' }, $table, $upload_fn, $id, { MIME => $mime } ); # cc20261109-6
    my $new_id    = $core->file_save( $upload->path, $table, $upload_fn, $id, { MIME => $mime } ); # cc20261109-6
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
#  $text .= "<p><h1>$browser_window_title</h1>";
  $text .= "<div class='record-table'>";
  $text .= "<div class='view-header view-sep record-sep fmt-center'>$browser_window_title</div>";

  my $record_name     = des_attr( $sdes, qw( WEB VIEW RECORD_NAME ) );
  # the record name is data: escaped, the title is html (shown in the ps path and its hints); $field as in ps_path_add_by_cue()
  # NOTE: placeholders are matched in any case now ($name too, upper-cased as in ps_path_add_by_cue()), an unknown field gives ''
  $record_name =~ s/\$(\w+)/exists $row_data->{ uc $1 } ? html_text( $row_data->{ uc $1 } ) : ''/ge;
  $browser_window_title .= " | $record_name" if $record_name ne ''; # no separator without a record name
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
    my $type_name  = des_type_name( $lfdes );
    my $type_lname = $lfdes->{ 'TYPE' }{ 'LNAME' };


    next if ! $user_is_root and des_attr( $bfdes, qw( WEB VIEW HIDE ) );

    my $lpassword = des_attr( $lfdes, 'PASSWORD' ) ? 1 : 0;

    my $label     = des_attr( $bfdes, qw( WEB VIEW LABEL ) );

#    my $label = "$blabel";
#    if( $bfdes ne $lfdes )
#      {
#      my $llabel     = des_attr( $lfdes, qw( WEB VIEW LABEL ) );
#      $label .= "/$llabel";
#      }

    my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

    my $data      = $row_data->{ $field };
    next if des_attr( $bfdes, qw( WEB VIEW HIDE_IF_EMPTY ) ) and type_is_empty( $type_name, $data );

    my $data_base = exists $basef{ $field } ? $row_data->{ $basef{ $field } } : undef; # no "my ... if", it may keep the previous field's value
    my ( $data_fmt, $data_fmt_class );
    my $data_ctrl;
    my $field_details;
    my $no_layout_ctrls = 0;


    my $overflow  = des_attr( $bfdes, qw( WEB VIEW OVERFLOW ) );
    # OVERFLOW: the data in a read-only input, set below after the formatting

    my $same_data_search; # FIXME: !!!
    if( des_is_linked( $bfdes ) or des_is_widelinked( $bfdes ) )
      {
      ( $data_fmt, $data_fmt_class )  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id, CORE => $core } );

      my ( $linked_table, $linked_field );
      if( des_is_widelinked( $bfdes ) )
        {
        $same_data_search = $data; # FIXME: !!!
        ( $linked_table, $data_base, $linked_field ) = type_widelink_parse2( $data );

        my $ltdes = $core->describe( $linked_table );
        if( $ltdes )
          {
          my $linked_table_label = des_table_label( $ltdes );
          if( $linked_field )
            {
            $data_fmt = $core->read_field( $linked_table, $linked_field, $data_base );
            my $wl_fdes = des_fld( $ltdes, $linked_field ); # widelinked field description, no longer shadows the loop $lfdes
            ( $data_fmt, $data_fmt_class ) = de_web_format_field( $data_fmt, $wl_fdes, 'VIEW', { ID => $data_base, CORE => $core } ); # with CORE like the other view cells, the class of the widelinked field
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
        ( $linked_table, $linked_field ) = des_link_details( $bfdes );
        }

      my $ltdes = $core->describe( $linked_table );
      $data_fmt =~ s/(<[^>]*>)|\./ defined $1 ? $1 : '&#46;' /ge; # dots in the text only (no name.png icon rewrite in the link), not inside tags

      if( $ltdes )
        {
        if( des_table_type( $ltdes ) eq 'FILE' )
          {
          if( $data_base > 0 )
            {
            # my $cue_dn_file = des_cue( qw( ) );
            $data_fmt   = de_html_alink(      $reo, 'new', "$data_fmt",    "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'view.svg',     "[~View linked record]",              ACTION => 'view',    ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_up.svg',  "[~Upload and replace current file]", ACTION => 'file_up', ID => $data_base, TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_dn.svg',  "[~Download current file]",           ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );

            # FIXME: TODO: set option
            $field_details .= ' ' . html_element( 'iframe', '', src => '?_=' . $reo->args_type( 'new', ACTION => 'file_dn', TABLE => $linked_table, ID => $data_base ), width => '100%', height => '700px' ) . ' ';
            }
          else
            {
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload new file]",                 ACTION => 'file_up', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            }
          }
        else
          {
          my $enum = des_table_type( $ltdes ) eq 'ENUM';
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

          if( des_is_linked( $bfdes ) and de_web_profile()->allows( $ltdes, 'INSERT' ) and de_web_profile()->allows( $tdes, 'UPDATE' ) and de_web_profile()->allows( $bfdes, 'UPDATE' ) )
            {
            # FIXME: check for record access too!
            my $insert_cue = des_attr( $bfdes, qw( WEB VIEW LINK_INSERT_CUE ) ) || "[~Insert and link a new record]";
            $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.svg', $insert_cue, ACTION => 'edit', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            }
          }
        } # if $ltdes
      else
        {
        $data_fmt = "[~(n/a)]";
        }
      }
    elsif( des_is_backlinked( $bfdes ) )
      {
      my ( $backlinked_table, $backlinked_field, $backlinked_src ) = des_backlink_details( $bfdes );
      my $bltdes = $core->describe( $backlinked_table );

      my $backlinked_src_data = $row_data->{ $backlinked_src };

      my $linked_table_label = des_table_label( $bltdes );

      my ( $backlink_insert_cue, $backlink_insert_cue_hint ) = des_cue( $bfdes, qw( WEB VIEW BACKLINK_INSERT_CUE ) );

      if( uc( des_attr( $bfdes, 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all related records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } );
        }
      else
        {
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'grid.svg',   "[~View all connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $backlinked_src_data, LINK_FIELD_VALUE => $backlinked_src_data, FILTER => { $backlinked_field => $backlinked_src_data } );
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'attach.svg', "[~View NOT connected records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $backlinked_src_data, LINK_FIELD_VALUE =>                    0, FILTER => { $backlinked_field =>                    0 } );
        }

      if( de_web_profile()->allows( $bltdes, 'INSERT' ) )
        {
        if( des_table_type( $bltdes ) eq 'FILE' )
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'file_new.svg', "[~Upload and link new files]", ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 );
          }
        else
          {
          $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.svg', "[~Create and connect a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $backlinked_src_data, LINK_FIELD_DISABLE => $backlinked_field, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id );
          }
        }

      if( de_web_profile()->allows( $bltdes, 'READ' ) )
        {
        my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
#        $count = 'Unknown' if $count eq '';
        my $uncount = $core->count( $backlinked_table, { FILTER => { $backlinked_field => 0 } });
#        my $acount  = $core->count( $backlinked_table, );

        my $count_s   = str_num_comma( $count   );
        my $uncount_s = str_num_comma( $uncount );

        $data_fmt = undef;
        $data_fmt .= de_html_alink( $reo, 'new', "<b class=hi>$count_s</b> [~items]",   "[~View all related items]",                  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_VALUE => $id, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } );
        $data_fmt .= de_html_alink( $reo, 'new', " ( + <b class=hi>$uncount_s</b> [~NOT connected])",   "[~View all related items]",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_VALUE =>   0,                       FILTER => { $backlinked_field =>   0 } ) if $uncount > 0;

        my $detail_fields = des_attr( $bfdes, qw( WEB EDIT DETAIL_FIELDS ) );
        if( $detail_fields )
          {
          my $backlink_text = "<p>";

          $detail_fields = join ',', @{ des_fields_list_by_oper( $bltdes, 'READ', de_web_profile() ) } if $detail_fields eq '*'; # only fields the user may read

          my $bltsdes = des_table_des( $bltdes );
          my $bltable_type = des_table_type( $bltdes );
          my ( $view_cue,   $view_cue_hint   ) = des_cue( $bltsdes, qw( WEB GRID VIEW_CUE   ) );
          my ( $update_cue, $update_cue_hint ) = des_cue( $bltsdes, qw( WEB GRID UPDATE_CUE ) );
          my ( $copy_cue,   $copy_cue_hint   ) = des_cue( $bltsdes, qw( WEB GRID COPY_CUE   ) );
          my ( $download_file_cue, $download_file_cue_hint ) = des_cue( $bltsdes, qw( WEB GRID DOWNLOAD_FILE_CUE ) );

          my $sub_de_data_grid_cb = sub
            {
            my $cbid = shift;
            my $vec_ctrl;
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "view.svg",    $view_cue_hint,          ACTION => 'view',    ID => $cbid, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, LINK_FIELD_DISABLE => $backlinked_field  );
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "edit.svg",    $update_cue_hint,        ACTION => 'edit',    ID => $cbid, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, ) if de_web_profile()->allows( $bltdes, 'UPDATE' );
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', "copy.svg",    $copy_cue_hint,          ACTION => 'edit',    ID =>    -1, TABLE => $backlinked_table, MASTER_RECORD_TABLE => $table, MASTER_RECORD_ID => $id, COPY_ID => $cbid, LINK_FIELD_DISABLE => $backlinked_field, "F:$backlinked_field" => $id ) if de_web_profile()->allows( $bltdes, 'INSERT' ) and ! des_attr( $bltsdes, 'NO_COPY' );
            $vec_ctrl .= de_html_alink_icon( $reo, 'new', 'file_dn.svg', $download_file_cue_hint, ACTION => 'file_dn', ID => $cbid, TABLE => $backlinked_table                                                          ) if $bltable_type eq 'FILE';
            return $vec_ctrl;
            };

          my $details_limit = des_attr( $bfdes, qw( WEB VIEW DETAILS_LIMIT ) ) || 16;

          my ( $dd_grid, $dd_count ) = de_data_grid( $core, $backlinked_table, $detail_fields, { FILTER => { $backlinked_field => $id }, LIMIT => $details_limit, CLASS => 'grid view record', TITLE => "[~Related] $linked_table_label", CTRL_CB => $sub_de_data_grid_cb, SUMS => 0 } ) ;
          $field_details .= $dd_grid;

          if( uc( des_attr( $bfdes, 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
            {
            $field_details .= de_html_alink_button( $reo, 'new', "[~View all related records] ($count_s)",   "[~View all related records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } ) unless $count <= $dd_count;
            }
          else
            {
            $field_details .= de_html_alink_button( $reo, 'new', " grid.svg [~View all] <b>$linked_table_label</b>  ($count_s)",     "[~View all connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => $id, FILTER => { $backlinked_field => $id } ) unless $count <= $dd_count; # de_html_alink*() make the icon of a bare name.svg, an <img src=...> in the label gets rewritten
            $field_details .= de_html_alink_button( $reo, 'new', " attach.svg [~View unattached] <b>$linked_table_label</b>",   "[~View all not connected records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, LINK_FIELD_VALUE => 0, FILTER => { $backlinked_field => 0 } ) if $uncount > 0; # de_html_alink*() make the icon of a bare name.svg, an <img src=...> in the label gets rewritten
            }

          if( de_web_profile()->allows( $bltdes, 'INSERT' ) )
            {
            if( des_table_type( $bltdes ) eq 'FILE' )
              {
              $field_details .= de_html_alink_button( $reo, 'new', '  file_new.svg [~Upload new file]', "[~Upload and link new files]", BTYPE => 'act', ACTION => 'file_up', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field, MULTI => 1 ); # de_html_alink*() make the icon of a bare name.svg, an <img src=...> in the label gets rewritten
              }
            else
              {
              my ( $insert_cue, $insert_cue_hint ) = des_cue( $bltsdes, qw( WEB GRID INSERT_CUE ) );
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
    elsif( $overflow )
      {
      # long data scrolls in a read-only input, the value is the data, html_element() escapes it
      # NOTE: it is the raw field data, for a linked field the link id, not the linked text (the old block ran before the formatting and always showed an empty input)
#-      $data_fmt = "<form>" . html_element( 'input', undef, value => $data, style => 'width: 96%', readonly => undef ) . "</form>"; # cc20261115-12
      $data_fmt = "<form>" . html_element( 'input', undef, value => $data, style => 'width: 96%', readonly => \ undef ) . "</form>"; # cc20261115-12 bare, undef leaves it out
      }

    if( $type_name eq 'CHAR' and $type_lname eq 'LOCATION' )
      {
      $data_fmt = html_alink( $reo, 'new', html_element( 'img', undef, class => 'icon', src => 'i/map_location.svg' ) . " $data_fmt", { HINT => '[~View map location]', CLASS => 'button ' }, ACTION => 'map_location', LL => $data ); # html_alink() with the de_html_alink_button() classes: de_html_alink_button() turns any name.svg/png text in the label (the data) into an icon
      }

    my $divider = des_attr( $bfdes, 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='view-divider view-sep record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

#    my $data_layout = $no_layout_ctrls ? $data_fmt : html_layout_2lr_flex( $data_fmt, $data_ctrl, '<==1>' );
#-    my $data_layout = $no_layout_ctrls ? $data_fmt : html_hbox( '<100,1n>', $data_fmt, $data_ctrl ); # cc20261116-2
    my $data_layout = $no_layout_ctrls ? $data_fmt : html_hbox( '<100,1n>', \ $data_fmt, \ $data_ctrl ); # html cells as \ $html, the new Layout escapes plain values # cc20261116-2
    my $base_field_class = lc "css_view_class_$base_field";
#    $text .= "<tr class=view>";
#    $text .= "<td class='view-field record-field $base_field_class                ' >$label</td>";
#    $text .= "<td class='view-value record-value $base_field_class $data_fmt_class' >$data_layout</td>";
#    $text .= "</tr>\n";

    my $record_first_class = $record_first ? 'record-first' : ''; # no "my ... if"
    $record_first = 0;
#-    $text .= "<div class='record-field-value'> # cc20261110-5
#-                <div class='view-field record-field $record_first_class $base_field_class                ' ><div>$label</div></div> # cc20261110-5
#-                <div class='view-value record-value $record_first_class $base_field_class $data_fmt_class' ><div>$data_layout</div></div> # cc20261110-5
#-              </div>"; # cc20261110-5
    $text .= html_element( 'div', "\n" # cc20261110-5
                . html_element( 'div', "<div>$label</div>",       class => "view-field record-field $record_first_class $base_field_class" ) . "\n" # cc20261110-5
                . html_element( 'div', "<div>$data_layout</div>", class => "view-value record-value $record_first_class $base_field_class $data_fmt_class" ) . "\n", # cc20261110-5
              class => 'record-field-value' ); # cc20261110-5

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
  $text .= de_html_alink_button( $reo, 'back', "(<) [~Back]", "[~Return to previous screen]$back_hint", BTYPE => 'nav' ) if $rs;
  if( de_web_profile()->allows( $tdes, 'UPDATE' ) )
    {
    my ( $update_cue, $update_cue_hint ) = des_cue( $sdes, qw( WEB GRID UPDATE_CUE ) ); # label and hint, as for copy
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$update_cue (^)", $update_cue_hint, BTYPE => 'mod', ACTION => 'edit', ID => $id, TABLE => $table, LINK_FIELD_DISABLE => $link_field_disable, MASTER_RECORD_TABLE => $master_record_table, MASTER_RECORD_ID => $master_record_id );
    }

  if( $table_type ne 'FILE' and de_web_profile()->allows( $tdes, 'INSERT' ) and ! des_attr( $sdes, 'NO_COPY' ) )
    {
    # my $copy_cue = des_attr( $sdes, qw( WEB GRID COPY_CUE ) ) || "[~Copy this record as new]";
    my ( $copy_cue, $copy_cue_hint ) = des_cue( $sdes, qw( WEB GRID COPY_CUE ) );
    # FIXME: row access!
    $text .= de_html_alink_button( $reo, 'new',  "$copy_cue (+)", $copy_cue_hint, BTYPE => 'act', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    }

  if( $table_type eq 'FILE' )
    {
    my $download_cue = des_attr( $sdes, qw( WEB GRID DOWNLOAD_CUE ) ) || '[~Download file]';
    $text .= de_html_alink_button( $reo, 'new', "(&darr;) $download_cue", undef,   BTYPE => 'act', ACTION => 'file_dn',     TABLE => $table, ID => $id,                  );

    if( de_web_profile()->allows( $tdes, 'UPDATE' ) )
      {
      my $upload_cue = des_attr( $sdes, qw( WEB GRID UPLOAD_CUE ) ) || "[~Re-Upload file]";
      #$text .= de_html_alink_button( $reo, 'new', "(&uarr;) $upload_cue", '[~Replace current file with new one]',   BTYPE => 'act', ACTION => 'file_up', TABLE => $table, ID => $id, );

      my $up_form = new Web::Reactor::HTML::Form( $reo );
      $text .= $up_form->begin( NAME => "form_up_$table" );
      $text .= $up_form->file_upload( NAME     => "UPLOAD_FILE", ID => "upload_file_input", ATTRS => { onChange => 'this.form.submit();', style => 'display: none' } );
      $text .= $up_form->button( NAME => "UPLOAD_FILE_OK", VALUE => $upload_cue, CLASS => "button mod-button", ATTRS => { onClick => 'document.getElementById("upload_file_input").click();return false;' } );
      $text .= $up_form->end();
      }
    }

  for my $do ( @{ des_category_list_by_oper( $tdes, 'DO', 'EXECUTE', de_web_profile() ) }  )
    {
    my $dodes   = des_category_des( $tdes, 'DO', $do );
    next if des_attr( $dodes, qw( WEB VIEW HIDE  ) );
    my $dolabel = des_attr( $dodes, qw( WEB VIEW LABEL ) );
    my $confirm = des_attr( $dodes, qw( CONFIRM ) ); # ask before running the DO, as grid.pm does
    $text .= de_html_alink_button( $reo, 'new',  "$dolabel &sect;", { HINT => undef, CONFIRM => $confirm }, ACTION => 'do', DO => $do, ID => $id, TABLE => $table ); # no hint, it only repeated the label # the DO CONFIRM, as in grid.pm
    }

  for my $act ( @{ des_category_list_by_oper( $tdes, 'ACTION', 'EXECUTE', de_web_profile() ) }  )
    {
    my $actdes   = des_category_des( $tdes, 'ACTION', $act );
    my $label  = des_attr( $actdes, 'LABEL'  );
    my $target = des_attr( $actdes, 'TARGET' ) || des_attr( $actdes, 'NAME' );
    my $icon   = lc( des_attr( $actdes, 'ICON' ) );
    $icon = $icon =~ /^[a-z_0-9]+\z/ ? "action_$icon.svg" : "action_generic.svg";
    $text .= de_html_alink_button( $reo, 'new', "$icon $label", $label, ACTION => $target, ID => $id, TABLE => $table );
    }


  $text .= de_html_alink_button( $reo, 'new', '[~Actions Log]', '[~View modifications made by users]', ACTION => 'alog_view', TABLE => $table, OID => $id );

  $text .= "<div class='record-table-envelope'>";
  $text .= join '', @backlinks_text;
  $text .= "</div>";

  $text .= "<#view_bottom_$table>";
  $text .= "<p>";

  return $text;
}

1;
