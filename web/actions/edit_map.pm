package decor::actions::edit_map;
use strict;
use Data::Dumper;
use Data::Tools;
use Decor::Web::HTML::Utils;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $table   = $reo->param( 'TABLE' );
  my $field   = $reo->param( 'FIELD' );
  my $id      = $reo->param( 'ID'    );

  my $ps = $reo->get_page_session();                                                                                            
  my $ui = $reo->get_user_input();

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $text;

  $text .= de_master_record_view( $reo );

  my $core = $reo->de_connect();

  my $tdes  = $core->describe( $table );
  my $fdes  = $tdes->get_field_des( $field );
  my ( $map_table, $map_near_field, $map_far_field ) = $fdes->map_details();

  my ( $far_ar, $far_field ) = de_web_read_map_far_table_data( $core, $table, $field, 'BODY' );
  my $map_data_ar = de_web_read_map_field_data( $core, $table, $field, $id );
  my $map_data  = { map { $_->{ $map_far_field } => $_->{ '_ID'   } } @$map_data_ar };
  my $map_state = { map { $_->{ $map_far_field } => $_->{ 'STATE' } } @$map_data_ar };

  if( $button eq 'OK' )
    {
    for my $row ( @$far_ar )
      {
      my $row_id = $row->{ '_ID' };
      my $value = !! $ui->{ "F:$row_id" };
      
      my $res;
      if( exists $map_data->{ $row_id } )
        {
        $res = $core->update( $map_table, { 'STATE' => $value }, { 'ID' => $map_data->{ $row_id } } );
        }
      else
        {
        $res = $core->insert( $map_table, { $map_near_field => $id, $map_far_field => $row_id, 'STATE' => $value } ) if $value;
        }  
      }
    return $reo->forward_back();
    }

#  $text .= "<xmp>" . Dumper( $far_ar, $map_data_ar, $map_data ) . "</xmp>";

  my $map_edit_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $map_edit_form_begin;
  $text .= $map_edit_form->begin( NAME => "form_edit_$table", DEFAULT_BUTTON => 'REDIRECT:OK' );
  my $form_id = $map_edit_form->get_id();

  $text .= "<div class='record-table'>";
  for my $row ( @$far_ar )
    {
    my $row_id = $row->{ '_ID' };
    my $value  = $map_state->{ $row_id };
    my $label  = $row->{ $far_field };
    my $field_input = $map_edit_form->checkbox_multi(
                                     NAME     => "F:$row_id",
                                     VALUE    => $value,
                                     RET      => [ '0', '1' ],
                                     LABELS   => [ qq( <img class="icon" src=i/check-edit-0.svg> ), qq( <img class="icon" src=i/check-edit-1.svg> ) ],
                                     );
                                     
    my $body = $row->{ 'BODY' };

    my $input_layout = html_layout_2lr( $field_input, "<div style='white-space: normal; padding: 0.5em;'><small>$body</small></div>", '<1==<' );
    $text .= "<div class='record-field-value'>
                <div class='view-field record-field fmt-right'>$label</div>
                <div class='view-value record-value fmt-left' >$input_layout</div>
              </div>";
    }
  $text .= "</div>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"   );
  $text .= $map_edit_form->button( NAME => 'OK', VALUE => "[~OK] &rArr;" );
  $text .= $map_edit_form->end();

  return $text;
}

1;
