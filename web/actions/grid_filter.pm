##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::grid_filter;
use strict;
use Data::Dumper;
use Exception::Sink;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;
use Decor::Web::View;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;

my $clear_icon = 'i/clear.svg';
my $clear_icon = 'x';

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table   = $reo->param( 'TABLE'   );

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  my $fields_ar;
  $fields_ar = $tdes->get_fields_list_by_oper( 'READ' );

  $reo->ps_path_add( 'filter', qq( "Filter records from "<b>$table_label</b>" ) );

#print STDERR Dumper( "error:", $fields_ar, $ps->{ 'ROW_DATA' }, 'insert', $edit_mode_insert, 'allow', $tdes->allows( 'UPDATE' ) );

  return "<#access_denied>" unless @$fields_ar;

  my $fields = join ',', @$fields_ar;

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority

  # handle redirects here
  de_web_handle_redirect_buttons( $reo );

  if( $button eq 'OK' )
    {
    my $filter_rules = {};
    my $filter_data  = {};

    my @fields = @$fields_ar;
    
    my %bfdes; # base/begin/origin field descriptions, indexed by field path
    my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
    my %basef; # base fields map, return base field NAME by field path

    de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

#      print STDERR "<hr><h2></h2><xmp style='text-align: left'>" . Dumper( \@fields, \%basef, \%bfdes, \%lfdes ) . "</xmp>";

    # compile rules
    for my $field_ex ( @fields )
      {
      my @field_filter;

      my $field     = $basef{ $field_ex } || $field_ex;
      my $field_out = $field;

      next unless exists $ui_si{ "F:$field" };
      
      my $input_data = $ui_si{ "F:$field" };
      $filter_data->{ $field_out } = $input_data; 

      $input_data =~ s/^\s*//;
      $input_data =~ s/\s*$//;
      next if $input_data eq '';

      # FIXME: links paths...
      my $bfdes     = $bfdes{ $field_ex };
      my $fdes      = $bfdes;

      my $combo = $fdes->get_attr( qw( WEB COMBO ) );
      if( $bfdes->is_linked() and ! $combo )
        {
        $fdes      = $lfdes{ $field_ex };
        $field_out = $field_ex;
        }
      
      my $type      = $fdes->{ 'TYPE'  };
      my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };


      if( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
        {
        next if $input_data == 0;
        my $ind;
        $ind = 0 if $input_data == 1;
        $ind = 1 if $input_data == 2;
        push @field_filter, { OP => '==', VALUE => $ind, };
        }
      elsif( $type_name eq 'CHAR' )
        {
        if( $input_data =~ s/\*/%/g )
          {
          push @field_filter, { OP => 'LIKE', VALUE => $input_data, };
          }
        else
          {  
          push @field_filter, { OP => '==', VALUE => $input_data, };
          }
        }  
      else
        {
        if( $input_data =~ /(\S*?)\s*\.\.+\s*(\S*)/ )
          {
          my $fr = $1;
          my $to = $2;
          next if $fr eq '' and $to eq '';
          ( $fr, $to ) = ( $to, $fr ) if $fr ne '' and $to ne '' and $fr > $to;

          $fr = type_revert( $fr, $type );
          $to = type_revert( $to, $type );
          
          push @field_filter, { OP => '>=', VALUE => $fr, } if $fr ne '';
          push @field_filter, { OP => '<=', VALUE => $to, } if $to ne '';
          }
        else
          {  
          my $eq = type_revert( $input_data, $type );
          push @field_filter, { OP => '==', VALUE => $eq, };
          }
        }  

      next unless @field_filter > 0;
      $filter_rules->{ $field_out } = \@field_filter; 
      }
    
#    $text .= "<xmp style='text-align: left;'>" . Dumper( $filter_rules, $filter_data ) . "</xmp>";
    $rs->{ 'FILTERS' }{ 'ACTIVE' }{ 'RULES' } = $filter_rules;
    $rs->{ 'FILTERS' }{ 'ACTIVE' }{ 'DATA'  } = $filter_data;
    return $reo->forward_back();
    }


###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  $text .= "<br>";

  my $filter_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $filter_form_begin;
  $filter_form_begin .= $filter_form->begin( NAME => "form_filter_$table", DEFAULT_BUTTON => 'OK' );
  my $form_id = $filter_form->get_id();
  $filter_form_begin .= "<p>";

  $text .= $filter_form_begin;

  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>[~Field]</td>";
  $text .= "<td class='view-header fmt-left' >[~Value]</td>";
  $text .= "</tr>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };

  for my $field ( @$fields_ar )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/preview/grid, bfdes is begin/origin-field
    my $type      = $fdes->{ 'TYPE'  };
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->{ 'LABEL' } || $field;

    next if $fdes->get_attr( 'WEB', 'HIDDEN' );

    my $input_data = $ui_si{ "F:$field" } || ( $rs->{ 'FILTERS' }{ 'ACTIVE' } ? $rs->{ 'FILTERS' }{ 'ACTIVE' }{ 'DATA' }{ $field } : undef );

    my $field_error;

    my $field_id = "F:$table:$field:" . $reo->html_new_id();

    my $field_input;
    my $field_input_ctrl;
    my $input_tag_args;
    my $field_disabled;

    my $combo = $fdes->get_attr( qw( WEB COMBO ) );

    if( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
      {
      $input_data = 0 if $input_data < 0;
      $input_data = 2 if $input_data > 2;
      $field_input .= $filter_form->checkbox_multi(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $input_data,
                                       STAGES   => 3,
                                       RET      => [ '0', '1', '2' ],
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       LABELS   => [ "<img class=check-unknown src=i/check-unknown.svg>", "<img class=check-0 src=i/check-0.svg>", "<img class=check-1 src=i/check-1.svg>" ],
                                       );
      }
    elsif( $bfdes->is_linked() and $combo )
      {
      my ( $linked_table, $linked_field ) = $bfdes->link_details();
      my $ltdes = $core->describe( $linked_table );
      
      my $spf_fmt;
      my @spf_fld;
      if( $combo == 1 or $combo eq '' )
        {
        $spf_fmt = "%s";
        @spf_fld = ( $linked_field );
        }
      else
        {
        my @v = split /\s*;\s*/, $combo;
        $spf_fmt = shift @v;
        @spf_fld = @v;
        }

      my $combo_data = [];
      my $sel_hr     = {};
      $sel_hr->{ $input_data } = 1 if $input_data > 0;

      my @lfields = @{ $ltdes->get_fields_list_by_oper( 'READ' ) };
      unshift @lfields, $linked_field;

      my %bfdes; # base/begin/origin field descriptions, indexed by field path
      my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
      my %basef; # base fields map, return base field NAME by field path

      de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

      my $lfields = join ',', '_ID', @lfields, values %basef;

      # $text .= "<hr><h2>$field</h2><xmp style='text-align: left'>" . Dumper( \@lfields, $lfields, \%basef, \%bfdes, \%lfdes ) . "</xmp>";

      my $combo_orderby = $fdes->get_attr( qw( WEB COMBO ORDERBY ) ) || join( ',', @spf_fld );
      my $combo_select  = $core->select( $linked_table, $lfields, { ORDER_BY => $combo_orderby } );
      
      push @$combo_data, { KEY => '', VALUE => '--' };
      
#$text .= "my $combo_select = $core->select( $linked_table, $lfields )<br>";
      while( my $hr = $core->fetch( $combo_select ) )
        {
        my @value = map { $hr->{ $_ } } @spf_fld;
        my $value = sprintf( $spf_fmt, @value );

#$text .= "[$spf_fmt][@spf_fld][$value][@value]<br>";
        $value =~ s/\s/&nbsp;/g;
        push @$combo_data, { KEY => $hr->{ '_ID' }, VALUE => $value };
        }

      my $fmt_class;
      if( $fdes->get_attr( 'WEB', 'EDIT', 'MONO' ) )
        {
        $fmt_class .= " fmt-mono";
        }

      $field_input = $filter_form->combo( NAME => "F:$field", CLASS => $fmt_class, DATA => $combo_data, SELECTED => $sel_hr );
      }
    elsif( $bfdes->is_backlinked() )
      {
      # cannot be filtered for now...
      # should be used as INT, to filter backlinked records count
      next;
      }
    else
      {
      my $field_size = 64;
      my $field_maxlen = $field_size;
      $field_input .= $filter_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $input_data,
                                       SIZE     => $field_size,
                                       MAXLEN   => $field_size * 10,
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      }  

    $field_error = "<div class=warning align=right>$field_error</div>" if $field_error;

    my $input_layout = html_layout_2lr( $field_input, $field_input_ctrl, '<==1>' );
    $text .= "<tr class=view>\n";
    $text .= "<td class='view-field'>$label$field_error</td>\n";
    $text .= "<td class='view-value' >$input_layout</td>\n";
    $text .= "</tr>\n";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"   );
  $text .= $filter_form->button( NAME => 'OK', VALUE => "[~OK] &rArr;" );
#  $text .= de_html_form_button( $reo, 'here', $filter_form, 'OK', "[~OK] &rArr;", "Filter records now" );
  $text .= $filter_form->end();

  return $text;
}

1;
