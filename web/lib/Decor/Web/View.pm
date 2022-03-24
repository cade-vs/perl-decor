##############################################################################
##
##  Decor application machinery core
##  2014-2022 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::View;
use strict;
use Data::Dumper;
use Exception::Sink;
use Time::JulianDay;
use Data::Tools;
use Data::Tools::Time;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;

use Web::Reactor::HTML::Layout;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_web_expand_resolve_fields_in_place

                de_web_format_phones
                de_web_format_field
                

                de_data_grid
                de_data_view

                );

sub de_web_expand_resolve_fields_in_place
{
  my $fields = shift; # array ref with fields
  my $tdes   = shift; # table description
  my $bfdes  = shift; # hashref base/begin/origin field descriptions, indexed by field path
  my $lfdes  = shift; # hashref linked/last       field descriptions, indexed by field path, pointing to trail field
  my $basef  = shift; # base fields

  my @res_fields;
  my $table = $tdes->get_table_name();

  #print STDERR Dumper( $fields, $tdes->{ 'FIELD' }, '---------------------------+++---'  );
  for( @$fields )
    {
    # resolve fields
    if( /\./ )
      {
      ( $bfdes->{ $_ }, $lfdes->{ $_ } ) = $tdes->resolve_path( $_ );
      $basef->{ $_ } = $bfdes->{ $_ }->{ 'NAME' };
      }
    else
      {
      boom "unknown FIELD NAME [$_] for TABLE [$table]" unless exists $tdes->{ 'FIELD' }{ $_ };
      my $fdes    = $tdes->{ 'FIELD' }{ $_ };
      if( $fdes->is_linked() )
        {
        my ( $xf, $ldes ) = $fdes->expand_field_path();
        $lfdes->{ $_  } = $ldes;
        $lfdes->{ $xf } = $ldes;
        $basef->{ $xf } = $fdes->{ 'NAME' };
        $_ = $xf;
        }
      else
        {
        $lfdes->{ $_ } = $fdes;
        }
      $bfdes->{ $_ } = $fdes;
      }
    }

  return undef;
}

sub de_web_format_phones
{
  my $phones = shift;
  my $wide   = shift;
  
  my @phones = split /\s*[,;]+\s*/, $phones;
  
  return undef unless @phones;
  
  s/^\s*// for @phones;
  s/\s*$// for @phones;

  s{((\+|\*|00)?[\s\d]+)}{<a href='tel:$1'>$1</a>} for @phones;

  return join $wide ? ', ' : "<br><br>\n", @phones;
}


sub de_web_format_field
{
  my $field_data =    shift;
  my $fdes       =    shift;
  my $vtype      = uc shift;
  my $opts       =    shift || {};
  
  my $reo  = $opts->{ 'REO'  };
  my $core = $opts->{ 'CORE' };
  my $id   = $opts->{ 'ID' };

#boom "!!!!!!!!!!!!!!!!" unless $fdes;

  my $table = $fdes->table();
  my $fname = $fdes->name();
  my $type_name  = $fdes->{ 'TYPE' }{ 'NAME'  };
  my $type_lname = $fdes->{ 'TYPE' }{ 'LNAME' };

  my $data_fmt;
  my $fmt_class;

  my $password = ( $fdes->get_attr( 'PASSWORD' ) or $fname =~ /^PWD_/ ) ? 1 : 0;

  if( $type_name eq 'CHAR' )
    {
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    $data_fmt = str_html_escape( $data_fmt );

    $data_fmt = "[~(hidden)]" if $password and $data_fmt ne '';
    
    my $maxlen = $fdes->get_attr( 'WEB', $vtype, 'MAXLEN' );
    if( $maxlen )
      {
      $maxlen = 16 if $maxlen == 0 and $maxlen == 1; # default
      if( length( $data_fmt ) > abs( $maxlen ) )
        {
        if( $maxlen == 1 )
          {
          $data_fmt = [ "<img src=i/check-0.svg>", "<img src=i/check-1.svg>" ]->[ !! ( length( $data_fmt ) > 0 ) ];
          }
        elsif( $maxlen > 0  )
          {
          my $cut_len = int( ( abs( $maxlen ) - 3 ) / 2 );
          $data_fmt = substr( $data_fmt, 0, $cut_len ) . ' &hellip; ' . substr( $data_fmt, - $cut_len );
          }
        else
          {
          # i.e. negative value
          my $cut_len = int( ( abs( $maxlen ) - 3 ) );
          $data_fmt = substr( $data_fmt, 0, $cut_len ) . ' &hellip; ';
          }  
        }
      }
    
    # logical types
    if( $type_lname eq 'EMAIL' )  
      {
      my @data_fmt = split /\s*[,;]\s*/, $data_fmt;
      $data_fmt = undef;
      $data_fmt .= join '; ', map { "<a href='mailto:$_'>$_</a>" } @data_fmt;
      }
    elsif( $type_lname eq 'PHONE' )  
      {
      my @field_data = split /\s*[,;]\s*/, $field_data;
      $data_fmt = undef;
      $data_fmt .= join '; ', map { "<a href='tel:$_'>" . de_web_format_phones( $_, 1 ) . "</a>" } @field_data;
      }
      
    if( $fdes->get_attr( 'WEB', $vtype, 'MONO' ) )
      {
      $fmt_class .= " fmt-mono";
      $data_fmt = "<pre>$data_fmt</pre>";
      }
    }
  elsif( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
    {
    $data_fmt = $field_data > 0 ? '[&radic;]' : '[&nbsp;]';
    if( $fdes->get_attr( 'WEB', $vtype, 'EDITABLE' ) )
      {
      $data_fmt = [ "<img class='check-base check-0' src=i/check-0.svg>", "<img class='check-base check-1' src=i/check-1.svg>" ]->[ !! $field_data ];
      my $new_val = !!! $field_data || 0; # cap and reverse
      # FIXME: use reactor_none_href to avoid session creation?
      #$data_fmt = "<div class=vframe><a reactor_new_href=?_an=set_val&table=$table&fname=$fname&id=$id&value=$new_val&vtype=$vtype>$data_fmt</a></div>";
      $data_fmt = "<a reactor_here_href=?update_record_with_id=$id&F:$fname=$new_val>$data_fmt</a>";
      }
    else
      {
      $data_fmt = [ "<img src=i/check-0.svg>", "<img src=i/check-1.svg>" ]->[ !! $field_data ];
      }  
    $fmt_class .= " fmt-center";
    }
  elsif( $type_name eq 'INT' or $type_name eq 'REAL' )
    {
    #$fmt_class .= $field_data > 0 ? " hi" : ""; # FIXME: move to field options
    $data_fmt = type_format_human( $field_data, $fdes->{ 'TYPE' } );
    }
  elsif( $type_name eq 'UTIME' or $type_name eq 'TIME' )
    {
    return '&empty;' if $field_data == 0;
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    my $details = $fdes->get_attr( 'WEB', $vtype, 'DETAILS' );

    if( $details )
      {
      my $sep  = $details > 1 ? '<br>' : ' &nbsp; &Delta;';
      my $diff = unix_time_diff_in_words_relative( time() - $field_data );
      $diff =~ s/([a-z]{2,})/\[~$1\]/gi;
      $data_fmt .= " <span class=details-text>$sep $diff</span>";
      }
    }
  elsif( $type_name eq 'DATE' )
    {
    return '&empty;' if $field_data == 0; # -x-
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    my $details = $fdes->get_attr( 'WEB', $vtype, 'DETAILS' );

    if( $details )
      {
      my $sep  = $details > 1 ? '<br>' : ' &nbsp; &Delta;';
      my $diff = julian_date_diff_in_words_relative( gm_julian_day(time()) - $field_data );
      $diff =~ s/([a-z]{2,})/\[~$1\]/gi;
      $data_fmt .= " <span class=details-text>$sep $diff</span>";
      }
    }
  elsif( $type_name eq 'LINK' and $fdes->get_attr( 'WEB', $vtype, 'EDITABLE' ) )
    {
    my ( $linked_table, $linked_field ) = $fdes->link_details();
    my $ltdes = $core->describe( $linked_table );
    my $lfdes = $ltdes->get_field_des( $linked_field );

    my $linked_data = $core->read_field( $linked_table, $linked_field, $field_data );
    $data_fmt = $field_data > 0 ? type_format( $linked_data, $lfdes->{ 'TYPE' } ) : '&empty;';

    my $select_filter_name = $fdes->get_attr( 'WEB', 'SELECT_FILTER' );

    my $combo = $fdes->get_attr( qw( WEB COMBO ) );
    my $radio = $fdes->get_attr( qw( WEB RADIO ) );

    my $spf_fmt;
    my @spf_fld;
    if( $combo == 1 )
      {
      $spf_fmt = "%s";
      @spf_fld = ( $linked_field );
      }
    else
      {
      my @v = split /\s*;\s*/, $combo;
      @v = ( "%s", $linked_field ) unless @v;
      $spf_fmt = shift @v;
      @spf_fld = @v;
      }

    my @lfields = @{ $ltdes->get_fields_list_by_oper( 'READ' ) };
    unshift @lfields, $linked_field;

    my %bfdes; # base/begin/origin field descriptions, indexed by field path
    my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
    my %basef; # base fields map, return base field NAME by field path

    de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

    my $lfields = join ',', '_ID', @lfields, values %basef;

    my $combo_orderby = $fdes->get_attr( qw( WEB COMBO ORDERBY ) ) || join( ',', @spf_fld );
    my $combo_select = $core->select( $linked_table, $lfields, { 'FILTER_NAME' => $select_filter_name, ORDER_BY => $combo_orderby } );


    my $combo_form_text;
    my $combo_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
    
    $combo_form_text .= $combo_form->begin( NAME => $reo->create_uniq_id(), );
    $combo_form->state( 'UPDATE_RECORD_WITH_ID' => $id );

    my @combo_data;
    push @combo_data, { KEY => 0, VALUE => '&empty;' };
    while( my $hr = $core->fetch( $combo_select ) )
      {
      my @value = map { $hr->{ $_ } } @spf_fld;
      my $value = sprintf( $spf_fmt, @value );
      my $key   = $hr->{ '_ID' };
      push @combo_data, { KEY => $key, VALUE => $value };
      }


#print STDERR "**************************************************************: " . Dumper( \@combo_data );


    if( $fdes->get_attr( 'WEB', 'EDIT', 'MONO' ) )
      {
      $fmt_class .= " fmt-mono";
      }

    #$combo_form_text .= $combo_form->state(  NAME => '', VALUE => '' );
    $combo_form_text .= $combo_form->combo(  NAME     => "F:$fname", 
                                             CLASS    => $fmt_class, 
                                             DATA     => \@combo_data, 
                                             SELECTED => $field_data,
                                             RADIO    => $radio,
                                             
                                             EXTRA    => 'onchange="this.form.submit()"',
                                             );

    $combo_form_text .= $combo_form->end();

    $data_fmt = $combo_form_text;
    }
  else
    {
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    }

  return wantarray ? ( $data_fmt, ' ' . $fmt_class ) : $data_fmt;
}

### DATA VIEWS ###############################################################

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

  my $ctrl_cb  = $opt->{ 'CTRL_CB'  };
  my $order_by = $opt->{ 'ORDER_BY' } || '._ID';

  my $tdes = $core->describe( $table );
  
  my @fields = ref( $fields ) eq 'ARRAY' ? @$fields : split /\s*,\s*/, $fields;
  
  unshift @fields, '_ID';
  
  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $filter = $opt->{ 'FILTER' };
  my $limit  = $opt->{ 'LIMIT'  };
  my $class  = $opt->{ 'CLASS'  } || 'grid';
  my $title  = $opt->{ 'TITLE'  };

  my $select = $core->select( $table, join( ',', @fields ), { FILTER => $filter, LIMIT => $limit, ORDER_BY => $order_by } ) if @fields;
  #my $scount = $core->count( $table,                        { FILTER => $filter,                                        } ) if $select;
  #my $acount = $core->count( $table,                        { FILTER => { '_ID' > 0 },                                 } ) if $select;
  
  my $text;

  if( $title )
    {
    my $c = @fields + 1 * ( defined $ctrl_cb );
    $text .= "<div class='view-sep fmt-center' colspan=$c>$title</div>";
    }

  $text .= "<table class='$class' cellspacing=0 cellpadding=0>";
  
  $text .= "<tr class=grid-header>";
  
  $text .= "<td class='grid-header fmt-left'>Ctrl</td>" if $ctrl_cb;

  for my $field ( @fields )
    {
    next if $field eq '_ID';
    
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

    if( $ctrl_cb )
      {
      my $vec_ctrl = $ctrl_cb->( $id, $row_data );
      $text .= "<td class='grid-data fmt-ctrl fmt-mono'>$vec_ctrl</td>";
      }

    for my $field ( @fields )
      {
      next if $field eq '_ID';

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
  
#  return wantarray ? ( $text, $row_counter, $scount ) : $text;
  return wantarray ? ( $text, $row_counter ) : $text;
}

#-----------------------------------------------------------------------------

sub de_data_view
{
  my $core   = shift;
  
  my $table  = shift;
  my $fields = shift;
  my $id     = shift;
  my $opt    = shift || {};

  my $ctrl_cb  = $opt->{ 'CTRL_CB'  };
  my $order_by = $opt->{ 'ORDER_BY' } || '._ID';

  my $tdes = $core->describe( $table );
  
  my @fields = ref( $fields ) eq 'ARRAY' ? @$fields : split /\s*,\s*/, $fields;
  
  unshift @fields, '_ID';
  
  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $class  = $opt->{ 'CLASS'  } || 'view';
  my $title  = $opt->{ 'TITLE'  };

  my $select = $core->select( $table, join( ',', @fields ), { FILTER => { '_ID' => $id } } ) if @fields;
  
  my $row_data = $core->fetch( $select );
  return "<p><#no_data><p>" unless $row_data;

  my $text;

  $text .= "<table class='$class record' cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header record-field fmt-center' colspan=2>$title</td>";
  $text .= "</tr>";

  for my $field ( @fields )
    {
    next if $field eq '_ID';

    my $bfdes      = $bfdes{ $field };
    my $lfdes      = $lfdes{ $field };
    my $type_name  = $lfdes->{ 'TYPE' }{ 'NAME'  };
    my $type_lname = $lfdes->{ 'TYPE' }{ 'LNAME' };

    my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

    my $label     = $bfdes->get_attr( qw( WEB VIEW LABEL ) );

    my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

    my $data      = $row_data->{ $field };
    my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
    my ( $data_fmt, $data_fmt_class )  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id } );
    my $data_ctrl;
    my $field_details;
    my $no_layout_ctrls = 0;

    my $overflow  = $bfdes->get_attr( qw( WEB VIEW OVERFLOW ) );
    if( $overflow )
      {
      $data_fmt = str_html_escape( $data_fmt );
      $data_fmt = "<form><input value='$data_fmt' style='width: 96%' readonly></form>";
      }

    if( $lpassword )
      {
      $data_fmt = "[~(hidden)]";
      }

    if( $type_name eq 'CHAR' and $type_lname eq 'LOCATION' )
      {
      $data_fmt = str_html_escape( $data_fmt );
      # $data_fmt = de_html_alink_button( $reo, 'new', " <img src=i/map_location.svg> $data_fmt", "[~View map location]", ACTION => 'map_location', LL => $data );
      }

    my $divider = $bfdes->get_attr( 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<tr class=view-header>";
      $text .= "<td class='view-header record-field fmt-center' colspan=2>$divider</td>";
      $text .= "</tr>";
      }

    my $data_layout = $no_layout_ctrls ? $data_fmt : html_layout_2lr( $data_fmt, $data_ctrl, '<==1>' );
    my $base_field_class = lc "css_view_class_$base_field";
    $text .= "<tr class=view>";
    $text .= "<td class='view-field record-field $base_field_class                ' >$label</td>";
    $text .= "<td class='view-value record-value $base_field_class $data_fmt_class' >$data_layout</td>";
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

}

1;
