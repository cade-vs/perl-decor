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

  my $table  = $reo->param( 'TABLE'  );
  my $offset = $reo->param( 'OFFSET' );
  my $filter_param = $reo->param( 'FILTER' );
  my $page_size = $reo->param( 'PAGE_SIZE' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  $reo->ps_path_add( 'grid.png', qq( List data from "<b>$table_label</b>" ) );

  return "<#e_internal>" unless $tdes;

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );

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

  my %filter;
  
  %filter = ( %filter, %$filter_param ) if $filter_param;
  
  my $select = $core->select( $table, $fields, { FILTER => \%filter, OFFSET => $offset, LIMIT => $page_size, ORDER_BY => '_ID DESC' } ) if $fields;
  my $scount = $core->count( $table, { FILTER => \%filter } ) if $select;
  
#  $text .= "<br>";
  $text .= "<p>";

  my $text_grid_head;
  my $text_grid_body;
  my $text_grid_foot;
  my $text_grid_navi_left;
  my $text_grid_navi_right;
  my $text_grid_navi_mid;

  $text_grid_navi_left .= de_html_alink( $reo, 'new', "insert.png Insert new record", 'Insert new record', ACTION => 'edit', ID => -1, TABLE => $table );
  
  $text_grid_head .= "<table class=grid cellspacing=0 cellpadding=0>";
  $text_grid_head .= "<tr class=grid-header>";
  $text_grid_head .= "<td class='grid-header fmt-left'>Ctrl</td>";
  
  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';
    my $blabel    = $bfdes->get_attr( qw( WEB GRID LABEL ) );
    my $label = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB GRID LABEL ) );
      $label .= "/$llabel";
      }

    $text_grid_head .= "<td class='grid-header $fmt_class'>$label</td>";
    }
  $text_grid_head .= "</tr>";
  
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

      my $select_icon = "select-to.png";
      my $select_hint = 'Select this record';
      if( $select_key_data ne '' and $row_data->{ $return_data_from } eq $select_key_data )
        {
        $select_icon = "select-to-selected.png";
        $select_hint = 'This is the currently selected record';
        }
      $vec_ctrl .= de_html_alink( $reo, 'back', $select_icon, $select_hint, @return_args );
      }
    
    $vec_ctrl .= de_html_alink( $reo, 'new', "view.png", 'View this record', ACTION => 'view', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink( $reo, 'new', "edit.png", 'Edit this record', ACTION => 'edit', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink( $reo, 'new', "copy.png", 'Copy this record', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    
    $text_grid_body .= "<td class='grid-data fmt-ctrl'>$vec_ctrl</td>";
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
            $data_fmt   = de_html_alink( $reo, 'new', $data_fmt,                       "View linked record", ACTION => 'view', ID => $data_base, TABLE => $linked_table );
            }
          else
            {
            $data_fmt   = "(empty)";
            }  
          $data_ctrl .= de_html_alink( $reo, 'new', 'view.png View linked record',   undef,                ACTION => 'view', ID => $data_base, TABLE => $linked_table );
          $data_ctrl .= "<br>\n";
          if( $ltdes->allows( 'UPDATE' ) and $data_base > 0 )
            {
            # FIXME: check for record access too!
            $data_ctrl .= de_html_alink( $reo, 'new', 'edit.png Edit linked record', undef, ACTION => 'edit', ID => $data_base, TABLE => $linked_table );
            $data_ctrl .= "<br>\n";
            }
          if( $ltdes->allows( 'INSERT' ) and $tdes->allows( 'UPDATE' ) and $bfdes->allows( 'UPDATE' ) )
            {
            # FIXME: check for record access too!
            $data_ctrl .= de_html_alink( $reo, 'new', 'insert.png Insert and link a new record', undef, ACTION => 'edit', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
            $data_ctrl .= "<br>\n";
            }
          }  
        }
      elsif( $bfdes->is_backlinked() )
        {
        my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
        $data_ctrl .= de_html_alink( $reo, 'new', 'insert.png Insert and link a new record', undef, ACTION => 'edit', TABLE => $backlinked_table, ID => -1,  );
        $data_ctrl .= "<br>\n";
        $data_ctrl .= de_html_alink( $reo, 'new', 'grid.png View linked records',            undef, ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, FILTER => { $backlinked_field => $id } );
        $data_ctrl .= "<br>\n";
        }

      if( $lpassword )
        {
        $data_fmt = "(hidden)";
        }

      if( $data_ctrl )
        {
        $data_ctrl = de_html_popup_icon( $reo, 'more.png', $data_ctrl );
        $data_fmt = "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=left>$data_fmt</td><td align=right>&nbsp;$data_ctrl</td></tr></table>";
        }
      
      $text_grid_body .= "<td class='grid-data $fmt_class'>$data_fmt</td>";
      }
    $text_grid_body .= "</tr>";
    }
  $text_grid_foot .= "</table>";

  if( $row_counter == 0 )
    {
    $text .= "<p><div class=info-text>No data found</div>";
    }
  else
    {
    my $offset_prev = $offset - $page_size;
    my $offset_next = $offset + $page_size;
    my $offset_last = $scount - $page_size;
    
    $offset_prev = 0 if $offset_prev < 0;
    $offset_last = 0 if $offset_last < 0;
    
    $text_grid_navi_mid .= $offset > 0 ? "<a reactor_here_href=?offset=0><img src=i/page-prev.png> first page</a> | " : "<img src=i/page-prev.png> first page | ";
    $text_grid_navi_mid .= $offset > 0 ? "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.png> previous page</a> | " : "<img src=i/page-prev.png> previous page | ";
    $text_grid_navi_mid .= $offset_next < $scount ? "<a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.png></a> | " : "next page <img src=i/page-next.png> | ";
    $text_grid_navi_mid .= $offset_next < $scount ? "<a reactor_here_href=?offset=$offset_last>last page <img src=i/page-next.png></a> | " : "last page <img src=i/page-next.png> | ";
    
    #$text_grid_navi .= "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.png> previous page</a> | <a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.png> </a>";
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

    $text .= $text_grid_navi;
    $text .= $text_grid_head;
    $text .= $text_grid_body;
    $text .= $text_grid_foot;
    $text .= $text_grid_navi;
    }  


  return $text;
}

1;
