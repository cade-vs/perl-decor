##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::grid;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

my %FMT_CLASSES = (
                  'CHAR'  => 'fmt-left',
                  'DATE'  => 'fmt-left',
                  'TIME'  => 'fmt-left',
                  'UTIME' => 'fmt-left',

                  'INT'   => 'fmt-right fmt-mono',
                  'REAL'  => 'fmt-right fmt-mono',
                  );

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $grid_mode  = $reo->param( 'GRID_MODE'  ) || 'NORMAL';

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $table  = $reo->param( 'TABLE'  );
  my $offset = $reo->param( 'OFFSET' );
  my $filter_param = $reo->param( 'FILTER' );
  my $page_size = $reo->param( 'PAGE_SIZE' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  $reo->ps_path_add( 'grid', qq( List data from "<b>$table_label</b>" ) );

  return "<#e_internal>" unless $tdes;

  if( $button eq 'DO' and $button_id )
    {
    # FIXME: check if exists
    my $do = $ps->{ ':DO_NAME_MAP' }{ $button_id };
    #return "<#e_access>" unless $do;
    
    my @do_ids;
    while( my ( $k, $v ) = each %$ui )
      {
      next unless $k =~ s/^VECB://;
      next unless $v > 0;
      push @do_ids, $ps->{ ':VECB_NAME_MAP' }{ $k } if exists $ps->{ ':VECB_NAME_MAP' }{ $k };
      }
    $text .= "[@do_ids][$do]";
    return $reo->forward_new( ACTION => 'do', DO => $do, IDS => \@do_ids, TABLE => $table ) if @do_ids;
    }

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );
  my $link_field_id      = $reo->param( 'LINK_FIELD_ID'      );
  my $filter_name = $reo->param( 'FILTER_NAME' );

#  print STDERR Dumper( $tdes );

  $page_size =  15 if $page_size <=   0;
  $page_size = 300 if $page_size >  300;
  $offset = 0 if $offset < 0;

  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };

### testing
#push @fields, 'USR.ACTIVE';

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $fields = join ',', @fields, values %basef;

  return "<#e_access>" unless $fields;

  my $last_filter = $ps->{ 'FILTERS' }{ 'LAST' };
  if( $last_filter and $reo->param_peek( 'USE_LAST_FILTER' ) )
    {
    $ps->{ 'FILTERS' }{ 'ACTIVE' } = $last_filter;
    }  

  my $active_filter = $ps->{ 'FILTERS' }{ 'ACTIVE' };
  if( $active_filter and $reo->param_peek( 'REMOVE_ACTIVE_FILTER' ) )
    {
    $ps->{ 'FILTERS' }{ 'LAST' } = $ps->{ 'FILTERS' }{ 'ACTIVE' };
    delete $ps->{ 'FILTERS' }{ 'ACTIVE' };
    $active_filter = undef;
    }
  
  my $filter = {};

  if( $active_filter )
    {
    $filter = $active_filter->{ 'RULES' };
    }
  else
    {  
    $filter = { %$filter, %$filter_param } if $filter_param;
    }

  my $select = $core->select( $table, $fields, { FILTER => $filter, FILTER_NAME => $filter_name, OFFSET => $offset, LIMIT => $page_size, ORDER_BY => '_ID DESC' } ) if $fields;
  my $scount = $core->count( $table, { FILTER => $filter, FILTER_NAME => $filter_name } ) if $select;

#  $text .= "<br>";
  $text .= "<p>";

#    $text .= "<xmp style='text-align: left;'>" . Dumper( $ps->{ 'FILTERS' } ) . "</xmp>";

  my $text_grid_head;
  my $text_grid_body;
  my $text_grid_foot;
  my $text_grid_navi_left;
  my $text_grid_navi_right;
  my $text_grid_navi_mid;

  
  my %insert_new_opts;
  
  if( $link_field_disable )
    {
    $insert_new_opts{ "F:$link_field_disable" } = $link_field_id;
    $insert_new_opts{ 'LINK_FIELD_DISABLE'    } = $link_field_disable;
    }
  
  $text_grid_navi_left .= de_html_alink( $reo, 'new', "insert.svg Insert new record", 'Insert new record', ACTION => 'edit',        TABLE => $table, ID => -1, %insert_new_opts ) if $tdes->allows( 'INSERT' );
  $text_grid_navi_left .= "&nbsp;";
  
  my $filter_link_label = $active_filter ? "Modify current filter" : "Filter records";
  $text_grid_navi_left .= de_html_alink( $reo, 'new', "filter.svg $filter_link_label",    'Filter records',    ACTION => 'grid_filter', TABLE => $table           );
  $text_grid_navi_left .= "&nbsp;";
  $text_grid_navi_left .= de_html_alink( $reo, 'here', "delete.svg Remove current filter",    'Remove current filter', REMOVE_ACTIVE_FILTER => 1 ) if $active_filter;
  $text_grid_navi_left .= "&nbsp;";
  $text_grid_navi_left .= de_html_alink( $reo, 'here', "filter.svg Enable last used filter",    'Enable last used filter', USE_LAST_FILTER => 1      )if $last_filter and ! $active_filter;

  $text_grid_head .= "<table class=grid cellspacing=0 cellpadding=0>";
  $text_grid_head .= "<tr class=grid-header>";
  $text_grid_head .= "<td class='grid-header fmt-left'>Ctrl</td>";

  @fields = grep { /^_/ ? $reo->user_has_group( 1 ) ? 1 : 0 : 1 } @fields;

  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';
    my $blabel    = $bfdes->get_attr( qw( WEB GRID LABEL ) );
    my $label     = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB GRID LABEL ) );
      $label .= "/$llabel";
      }

    $text_grid_head .= "<td class='grid-header $fmt_class'>$label</td>";
    }
  $text_grid_head .= "</tr>";

  my @dos;
  for my $do ( @{ $tdes->get_category_list_by_oper( 'READ', 'DO' ) }  )
    {
    my $dodes   = $tdes->get_category_des( 'DO', $do );
    next unless $dodes->allows( 'EXECUTE' );
    push @dos, $do;
    }

  my $grid_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $grid_form_begin;
  $grid_form_begin .= $grid_form->begin( NAME => "grid_edit_$table", DEFAULT_BUTTON => 'NOOP' );
  my $grid_form_id = $grid_form->get_id();

  delete $ps->{ ':VECB_NAME_MAP' };

  my $row_counter;
  while( my $row_data = $core->fetch( $select ) )
    {
    my $id = $row_data->{ '_ID' };

    my $row_class = $row_counter++ % 2 ? 'grid-1' : 'grid-2';
    $text_grid_body .= "<tr class=$row_class>";

    my $vec_ctrl;

    if( $grid_mode eq 'SELECT' )
      {
      my $return_data_from = $reo->param( 'RETURN_DATA_FROM' );
      my $return_data_to   = $reo->param( 'RETURN_DATA_TO'   );
      my $select_key_data  = $reo->param( 'SELECT_KEY_DATA'  );
      my @return_args;

      if( $return_data_from and $return_data_to )
        {
        push @return_args, ( "F:$return_data_to" => $row_data->{ $return_data_from } );
        }

      my $select_icon = "select-to.svg";
      my $select_hint = 'Select this record';
      if( $select_key_data ne '' and $row_data->{ $return_data_from } eq $select_key_data )
        {
        $select_icon = "select-to-selected.svg";
        $select_hint = 'This is the currently selected record';
        }
      $vec_ctrl .= de_html_alink( $reo, 'back', $select_icon, $select_hint, @return_args );
      }

    $vec_ctrl .= de_html_alink( $reo, 'new', "view.svg", 'View this record', ACTION => 'view', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink( $reo, 'new', "edit.svg", 'Edit this record', ACTION => 'edit', ID => $id, TABLE => $table ) if $tdes->allows( 'UPDATE' );
    $vec_ctrl .= de_html_alink( $reo, 'new', "copy.svg", 'Copy this record', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id ) if $tdes->allows( 'INSERT' );

    if( @dos )
      {
      my $cb_id = ++ $ps->{ ':VECB_NAME_MAP' }{ '*' };
      $ps->{ ':VECB_NAME_MAP' }{ $cb_id } = $id;
      $vec_ctrl .= $grid_form->checkbox_multi(
                                       NAME     => "VECB:$cb_id",
                                       ID       => "VECB:$cb_id",
                                       VALUE    => 0,
                                       RET      => [ '0', '1' ],
                                       LABELS   => [ "<img class=check-0 src=i/check-0.svg>", "<img class=check-1 src=i/check-1.svg>" ],
                                       );
      }

    $text_grid_body .= "<td class='grid-data fmt-ctrl fmt-mono'>$vec_ctrl</td>";
    for my $field ( @fields )
      {
      my $bfdes     = $bfdes{ $field };
      my $lfdes     = $lfdes{ $field };
      my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
      my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';

      my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

      my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

      my $data = $row_data->{ $field };
      my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };

      my ( $data_fmt, $fmt_class ) = de_web_format_field( $data, $lfdes, 'GRID' );
      my $data_ctrl;

      if( $bfdes->is_linked() )
        {
        if( $link_field_disable and $base_field eq $link_field_disable )
          {
          if( $data_base > 0 )
            {
            # TODO: highlight disabled links
            # $data_fmt   = $data_fmt;
            }
          else
            {
            $data_fmt   = "(empty)";
            }
          }
        else
          {
          my ( $linked_table, $linked_field ) = $bfdes->link_details();
          my $ltdes = $core->describe( $linked_table );
          if( $data_base > 0 )
            {
            $data_fmt =~ s/\./&#46;/g;
            if( $ltdes->get_table_type() eq 'FILE' )
              {
              $data_fmt   = de_html_alink( $reo, 'new', "$data_fmt",                       "View linked record", ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
              $data_ctrl .= de_html_alink( $reo, 'new', 'file_dn.svg Download file',       undef,                ACTION => 'file_dn', ID => $data_base, TABLE => $linked_table );
              $data_ctrl .= "<br>\n";
              }
            else
              {  
              $data_fmt   = de_html_alink( $reo, 'new', "$data_fmt",                       "View linked record", ACTION => 'view', ID => $data_base, TABLE => $linked_table );
              }
            }
          else
            {
            $data_fmt   = "(empty)";
            }
          $data_ctrl .= de_html_alink( $reo, 'new', 'view.svg View linked record',   undef,                ACTION => 'view', ID => $data_base, TABLE => $linked_table ) if $data_base > 0;
          $data_ctrl .= "<br>\n";
          if( $ltdes->allows( 'UPDATE' ) and $data_base > 0 )
            {
            # FIXME: check for record access too!
            $data_ctrl .= de_html_alink( $reo, 'new', 'edit.svg Edit linked record', undef, ACTION => 'edit', ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= "<br>\n";
            }
          if( $ltdes->allows( 'INSERT' ) and $tdes->allows( 'UPDATE' ) and $bfdes->allows( 'UPDATE' ) )
            {
            # FIXME: check for record access too!
            $data_ctrl .= de_html_alink( $reo, 'new', 'insert.svg Insert and link a new record', undef, ACTION => 'edit', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            $data_ctrl .= "<br>\n";
            }
          }
        }
      elsif( $bfdes->is_backlinked() )
        {
        my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
        $data_ctrl .= de_html_alink( $reo, 'new', 'insert.svg Insert and link a new record', undef, ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field );
        $data_ctrl .= "<br>\n";
        $data_ctrl .= de_html_alink( $reo, 'new', 'grid.svg View linked records',            undef, ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } );
        $data_ctrl .= "<br>\n";
        $data_fmt = ""; # TODO: hide count, which is currently unsupported
        }

      if( $lpassword )
        {
        $data_fmt = "(hidden)";
        }

      if( $data_ctrl )
        {
        $data_ctrl = de_html_popup_icon( $reo, 'more.svg', $data_ctrl );
        $data_fmt = "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=left>$data_fmt</td><td align=right>&nbsp;$data_ctrl</td></tr></table>";
        }

      $text_grid_body .= "<td class='grid-data $fmt_class'>$data_fmt</td>";
      }
    $text_grid_body .= "</tr>";
    }
  $text_grid_foot .= "</table>";

  if( $row_counter == 0 )
    {
    $text .= "<p><div class=info-text>No data found -- $text_grid_navi_left</div><p>";
    }
  else
    {
    my $offset_prev = $offset - $page_size;
    my $offset_next = $offset + $page_size;
    my $offset_last = $scount - $page_size;

    $offset_prev = 0 if $offset_prev < 0;
    $offset_last = 0 if $offset_last < 0;

    $text_grid_navi_mid .= $offset > 0 ? "<a reactor_here_href=?offset=0><img src=i/page-prev.svg> first page</a> | " : "<img src=i/page-prev.svg> first page | ";
    $text_grid_navi_mid .= $offset > 0 ? "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.svg> previous page</a> | " : "<img src=i/page-prev.svg> previous page | ";
    $text_grid_navi_mid .= $offset_next < $scount ? "<a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.svg></a> | " : "next page <img src=i/page-next.svg> | ";
    $text_grid_navi_mid .= $offset_next < $scount ? "<a reactor_here_href=?offset=$offset_last>last page <img src=i/page-next.svg></a> | " : "last page <img src=i/page-next.svg> | ";

    #$text_grid_navi .= "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.svg> previous page</a> | <a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.svg> </a>";
    my $page_more = int( $page_size * 2 );
    my $page_less = int( $page_size / 2 );
    my $link_page_more = de_html_alink( $reo, 'here', "+",       'Show more rows per page',   PAGE_SIZE => $page_more );
    my $link_page_less = de_html_alink( $reo, 'here', "&mdash;", 'Show less rows per page',   PAGE_SIZE => $page_less );
    my $link_page_all  = $scount <= 300 ? de_html_alink( $reo, 'here', "=",       'Show all rows in one page', PAGE_SIZE => $scount, OFFSET => 0 ) : '';
    $link_page_all = "/$link_page_all" if $link_page_all;

    my $offset_from = $offset + 1;
    my $offset_to   = $offset + $row_counter;
    $text_grid_navi_mid .= "rows $offset_from .. $offset_to ($page_size/$link_page_more/$link_page_less$link_page_all) of $scount";

    # FIXME: use function!
    my $text_grid_navi = "<table width=100% style='white-space: nowrap'><tr><td align=left width=1%>$text_grid_navi_left</td><td align=center>$text_grid_navi_mid</td><td align=right width=1%>$text_grid_navi_right</td></tr></table>";

    $text .= $grid_form_begin;
    
    $text .= $text_grid_navi;
    $text .= $text_grid_head;
    $text .= $text_grid_body;
    $text .= $text_grid_foot;
    $text .= $text_grid_navi;

    delete $ps->{ ':DO_NAME_MAP' };
    for my $do ( @dos )
      {
      my $dodes   = $tdes->get_category_des( 'DO', $do );
      my $dolabel = $dodes->get_attr( qw( WEB GRID LABEL ) );
      # FIXME: map DOs through $ps
      my $do_id = ++ $ps->{ ':DO_NAME_MAP' }{ '*' };
      $ps->{ ':DO_NAME_MAP' }{ $do_id } = $do;
      $text .= $grid_form->button( NAME => "DO:$do_id", VALUE => $dolabel );
      }
    
    $text .= $grid_form->end();
    
    }

  $text .=  "<p>" . de_html_alink_button( $reo, 'back', "&lArr; Go back", "Go back to the previous screen"   );

  return $text;
}

1;
