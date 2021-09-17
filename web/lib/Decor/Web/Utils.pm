##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::Utils;
use strict;

use Exception::Sink;
use Data::Tools;
use Web::Reactor::HTML::Utils;
use Decor::Web::View;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_handle_redirect_buttons
                
                de_web_get_cue
                
                de_data_grid
                
                );

##############################################################################

sub de_web_handle_redirect_buttons
{
  my $reo   = shift; # web::reactor object

  my $button    = $reo->get_input_button();
  return unless $button eq 'REDIRECT';

  my $button_id = $reo->get_input_button_id();
  my $ps        = $reo->get_page_session();

  if( ! exists $ps->{ 'BUTTON_REDIRECT' }{ $button_id } )
    {
    my $psid        = $reo->get_page_session_id();
    my $usid        = $reo->get_user_session_id();
    $reo->log( "error: requesting unknown REDIRECT [$button_id] usid [$usid] psid [$psid]" );
    return undef;
    }
    
  return $reo->forward_type( @{ $ps->{ 'BUTTON_REDIRECT' }{ $button_id } } );  
}

##############################################################################

sub de_web_get_cue
{
  my $des_obj = shift;
  
  my $cue = $des_obj->get_attr( @_ );
  if( ! $cue and ! $des_obj->is_self_category() )
    {
#use Data::Dumper;
#print STDERR Dumper( '+-*-' x 200, $des_obj->is_self_category(), $des_obj );

    $cue = $des_obj->get_self_des()->get_attr( @_ );
    }
  
  my @cue = split /\s*;\s*/, $cue;
  if( wantarray() )
    {
    if( @cue > 1 )
      {
      return @cue[ 0 ] if $cue[ 1 ] eq '-';
      return @cue[ 0, 1 ];
      }
    else
      {
      return @cue[ 0, 0 ];
      }  
    }
  else
    {
    return $cue[ 0 ];
    }  
}

##############################################################################

my %FMT_CLASSES = (
                  'CHAR'  => 'fmt-left',
                  'DATE'  => 'fmt-left',
                  'TIME'  => 'fmt-left',
                  'UTIME' => 'fmt-left',

                  'INT'   => 'fmt-right fmt-mono',
                  'REAL'  => 'fmt-right fmt-mono',
                  );

sub de_data_grid
{
  my $core   = shift;
  
  my $table  = shift;
  my $fields = shift;
  my $opt    = shift || {};

  my $tdes = $core->describe( $table );
  
  my @fields = ref( $fields ) eq 'ARRAY' ? @$fields : split /\s*,\s*/, $fields;
  
  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $filter = $opt->{ 'FILTER' };
  my $limit  = $opt->{ 'LIMIT'  };
  my $class  = $opt->{ 'CLASS'  } || 'grid';
  my $title  = $opt->{ 'TITLE'  };

  my $select = $core->select( $table, join( ',', @fields ), { FILTER => $filter, LIMIT => $limit, ORDER_BY => '._ID' } ) if @fields;
  #my $scount = $core->count( $table,                        { FILTER => $filter,                                     } ) if $select;
  #my $acount = $core->count( $table,                        { FILTER => { '_ID' > 0 },                               } ) if $select;
  
  my $text;

  $text .= "<table class='$class' cellspacing=0 cellpadding=0>";
  
  if( $title )
    {
    my $c = @fields;
    $text .= "<tr class=grid-header><td class='view-header fmt-center' colspan=$c>$title</td></tr>";
    }
  
  $text .= "<tr class=grid-header>";
  # $text .= "<td class='grid-header fmt-left'>Ctrl</td>";

  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';

    my $base_field = $bfdes->{ 'NAME' };

    my $blabel    = $bfdes->get_attr( qw( WEB GRID LABEL ) );
    my $label     = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB GRID LABEL ) );
      $label .= "/$llabel";
      }

    $text .= "<td class='grid-header $fmt_class'>$label</td>";
    }
  $text .= "</tr>";

  my $row_counter;
  while( my $row_data = $core->fetch( $select ) )
    {
    my $id = $row_data->{ '_ID' };

    my $row_class = $row_counter++ % 2 ? 'grid-1' : 'grid-2';
    $text .= "<tr class=$row_class>";

    # my $vec_ctrl; # FIXME: TODO: callback
    # $text .= "<td class='grid-data fmt-ctrl fmt-mono'>$vec_ctrl</td>";

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

      my ( $data_fmt, $fmt_class_fld ) = de_web_format_field( $data, $lfdes, 'GRID', { ID => $id } );
      my $data_ctrl;
      $fmt_class .= $fmt_class_fld;

      if( $lpassword )
        {
        $data_fmt = "(*****)";
        }

      my $base_field_class = lc "css_grid_class_$base_field";
      $text .= "<td class='grid-data $fmt_class  $base_field_class'>$data_fmt</td>";
      }
    $text .= "</tr>";
    }
  $text .= "</table>";
  
  return wantarray ? ( $text, $row_counter ) : $text;
}

### EOF ######################################################################
1;
