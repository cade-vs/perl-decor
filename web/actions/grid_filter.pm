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
    # compile rules
    for my $field ( @$fields_ar )
      {
      my @field_filter;

      next unless exists $ui_si{ "F:$field" };
      
      my $input_data = $ui_si{ "F:$field" };
      $filter_data->{ $field  } = $input_data; 

      $input_data =~ s/^\s*//;
      $input_data =~ s/\s*$//;
      next if $input_data eq '';

      # FIXME: links paths...
      my $fdes      = $tdes->{ 'FIELD' }{ $field };
      my $bfdes     = $fdes; # keep sync code with view/preview/grid, bfdes is begin/origin-field
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
        if( $input_data =~ /(\S*)\s*\.\.+\s*(\S*)/ )
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
          push @field_filter, { OP => '==', VALUE => $input_data, };
          }
        }  

      next unless @field_filter > 0;
      $filter_rules->{ $field } = \@field_filter; 
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
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
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

    my $input_data = $ui_si{ "F:$field" } || ( $rs->{ 'FILTERS' }{ 'ACTIVE' } ? $rs->{ 'FILTERS' }{ 'ACTIVE' }{ 'DATA' }{ $field } : undef );

    my $field_error;

    my $field_id = "F:$table:$field:" . $reo->html_new_id();

    my $field_input;
    my $field_input_ctrl;
    my $input_tag_args;
    my $field_disabled;


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
  $text .= de_html_alink_button( $reo, 'back', "&lArr; Cancel", "Cancel this operation"   );
  $text .= $filter_form->button( NAME => 'OK', VALUE => "[~OK] &rArr;" );
#  $text .= de_html_form_button( $reo, 'here', $filter_form, 'OK', "[~OK] &rArr;", "Filter records now" );
  $text .= $filter_form->end();

  return $text;
}

1;
