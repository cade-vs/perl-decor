##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::preview;
use strict;
use Data::Dumper;
use Data::Tools 1.21;
use Exception::Sink;

use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

#  my $table   = $reo->param( 'TABLE'   );
#  my $id      = $reo->param( 'ID'      );


  my $core = $reo->de_connect();

  my $ps = $reo->get_page_session();

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data>" unless $table and $id;

  my $tdes = $core->describe( $table );

  my @fields           = @{ $ps->{ 'FIELDS_WRITE_AR'  } };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  push @fields, @{ $tdes->get_fields_list_by_oper( 'READ' ) };
  @fields = $tdes->sort_fields_by_order( list_uniq( @fields ) );
  
  #print STDERR Dumper( '*'x200, \@fields, $tdes );

  return "<#access_denied>" unless @fields;

  my $text .= "<br>";

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>[~Field]</td>";
  $text .= "<td class='view-header fmt-left' >[~Value]</td>";
  $text .= "</tr>";

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;
  my $row_id = $row_data->{ '_ID' };

  @fields = grep { /^_/ ? $reo->user_has_group( 1 ) ? 1 : 0 : 1 } @fields;

  for my $field ( @fields )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/grid, bfdes is begin/origin-field
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->get_attr( qw( WEB PREVIEW LABEL ) );

    my $base_field = $field;

    my $data = $row_data->{ $field };
    my $data_fmt = de_web_format_field( $data, $fdes, 'PREVIEW' );

    if( $bfdes->is_linked() )
      {
      my ( $linked_table, $linked_field ) = $bfdes->link_details();
      my $ltdes = $core->describe( $linked_table );

      my $ldes = $core->describe( $linked_table );
      my @lfields = @{ $ldes->get_fields_list_by_oper( 'READ' ) };

###      return "<#access_denied>" unless @fields;

      my %bfdes; # base/begin/origin field descriptions, indexed by field path
      my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
      my %basef; # base fields map, return base field NAME by field path

      de_web_expand_resolve_fields_in_place( \@lfields, $ldes, \%bfdes, \%lfdes, \%basef );

    #$text .= Dumper( \%basef );

      my $lfields = join ',', @lfields, values %basef;

      my $lrow_data = $core->select_first1_by_id( $linked_table, $lfields, $data );

      $data_fmt = de_web_format_field( $lrow_data->{ $linked_field }, $lfdes{ $linked_field }, 'PREVIEW' );
      }
    elsif( $bfdes->is_backlinked() )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );
      my $linked_table_label = $bltdes->get_label();

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
      $count = 'Unknown' if $count eq '';

      $data_fmt = qq( <b class=hi>$count</b> [~records from] <b class=hi>$linked_table_label</b> );
      }

    my $base_field_class = lc "css_preview_class_$base_field";
    $text .= "<tr class=view>";
    $text .= "<td class='view-field  $base_field_class' >$label</td>";
    $text .= "<td class='view-value  $base_field_class' >$data_fmt</td>";
    $text .= "</tr>";
    }
  $text .= "</table>";

  my $ok_hint = $edit_mode_insert ? "[~Confirm new record insert]" : "[~Confirm record update]";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"                        );
  $text .= de_html_alink_button( $reo, 'here', "[~Edit] &uArr;",   "[~Back to data edit screen]", BTYPE => 'mod', ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'here', "[~OK] &radic;",     $ok_hint,                     ACTION => 'commit' );

  return $text;
}

1;
