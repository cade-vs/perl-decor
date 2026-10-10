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
use Decor::Shared::Describe;
use Data::Dumper;
use Exception::Sink;
use Time::JulianDay;
use Data::Tools;
use Data::Tools::Time;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;

use Web::Reactor::HTML::Layout;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_web_expand_resolve_fields_in_place

                de_web_format_phones
                de_web_format_field
                

                de_data_grid
                de_data_view

                de_master_record_view
                de_progress_bar

                );

sub de_web_expand_resolve_fields_in_place
{
  my $fields = shift; # array ref with fields
  my $tdes   = shift; # table description
  my $bfdes  = shift; # hashref base/begin/origin field descriptions, indexed by field path
  my $lfdes  = shift; # hashref linked/last       field descriptions, indexed by field path, pointing to trail field
  my $basef  = shift; # base fields

  my @res_fields;
  my $table = des_table_name( $tdes );

  #print STDERR Dumper( $fields, $tdes->{ 'FIELD' }, '---------------------------+++---'  );
  for( @$fields )
    {
    # resolve fields
    if( /\./ )
      {
      ( $bfdes->{ $_ }, $lfdes->{ $_ } ) = des_resolve( $tdes, $_ );
      $basef->{ $_ } = $bfdes->{ $_ }->{ 'NAME' };
      }
    else
      {
      boom "unknown FIELD NAME [$_] for TABLE [$table]" unless exists $tdes->{ 'FIELD' }{ $_ };
      my $fdes    = $tdes->{ 'FIELD' }{ $_ };
      if( des_is_linked( $fdes ) )
        {
        my ( $xf, $ldes ) = des_field_expand_path( $fdes );
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
  my $vtype      = uc shift; # view type, e.g. VIEW, EDIT...
  my $opts       =    shift || {};
  
  my $reo  = $opts->{ 'REO'  };
  my $core = $opts->{ 'CORE' };
  my $id   = $opts->{ 'ID' };

#boom "!!!!!!!!!!!!!!!!" unless $core;

  my $table = des_item_table( $fdes );
  my $fname = des_item_name( $fdes );
  my $type_name  = $fdes->{ 'TYPE' }{ 'NAME'  };
  my $type_lname = $fdes->{ 'TYPE' }{ 'LNAME' };

  my $editable = $opts->{ 'NO_EDIT' } ? undef : des_get_attr( $fdes, 'WEB', $vtype, 'EDITABLE' );

  my $data_fmt;
  my $fmt_class;

  my $password = ( des_get_attr( $fdes, 'PASSWORD' ) or $fname =~ /^PWD_/ ) ? 1 : 0;

  my $web_display = des_get_attr( $fdes, 'WEB', $vtype, 'DISPLAY' );

  if( $type_name =~ /^(CHAR|INT|REAL)$/ and $web_display =~ /^progress(-bar)?/i )
    {
    my $maxlen = des_get_attr( $fdes, 'WEB', $vtype, 'MAXLEN' );
    $data_fmt = de_progress_bar( $field_data, $maxlen );
    }
  elsif( $type_name eq 'CHAR' )
    {
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    $data_fmt = str_html_escape( $data_fmt );

    $data_fmt = "[~(hidden)]" if $password and $data_fmt ne '';
    
    my $maxlen = des_get_attr( $fdes, 'WEB', $vtype, 'MAXLEN' );
    if( $maxlen )
      {
      $maxlen = 16 if $maxlen == 0 and $maxlen == 1; # default
      if( length( $data_fmt ) > abs( $maxlen ) )
        {
        if( $maxlen == 1 )
          {
          $data_fmt = [ "<img src=i/check-view-0.svg>", "<img src=i/check-view-1.svg>" ]->[ !! ( length( $data_fmt ) > 0 ) ];
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

    $data_fmt = "&empty;" if $data_fmt eq '';
      
    my $fmt_mono = des_get_attr( $fdes, 'WEB', $vtype, 'MONO' );
    my $fmt_code = des_get_attr( $fdes, 'WEB', $vtype, 'CODE' );
    if( $fmt_mono or $fmt_code )
      {
      $fmt_class .= " fmt-mono";
      
      my $oo; # open
      my $cc; # close

      ( $oo, $cc ) = ( $oo . "<pre>",  "</pre>"  . $cc ) if $fmt_mono;
      ( $oo, $cc ) = ( $oo . "<code>", "</code>" . $cc ) if $fmt_code;
      
      $data_fmt = "$oo$data_fmt$cc";
      }
    }
  elsif( $type_lname eq 'BOOL' )
    {
    $data_fmt = $field_data > 0 ? '[&radic;]' : '[&nbsp;]';
    if( $editable )
      {
      $data_fmt = [ "<img src=i/check-view-0.svg>", "<img src=i/check-view-1.svg>" ]->[ !! $field_data ];
      my $new_val = !!! $field_data || 0; # cap and reverse
      # FIXME: use reactor_none_href to avoid session creation?
      #$data_fmt = "<div class=vframe><a reactor_new_href=?_an=set_val&table=$table&fname=$fname&id=$id&value=$new_val&vtype=$vtype>$data_fmt</a></div>";
      $data_fmt = "<a reactor_here_href=?update_record_with_id=$id&F:$fname=$new_val>$data_fmt</a>";
      }
    else
      {
      $data_fmt = [ "<img src=i/check-view-0.svg>", "<img src=i/check-view-1.svg>" ]->[ !! $field_data ];
      }  
    $fmt_class .= " fmt-center";
    }
  elsif( $type_name eq 'INT' or $type_name eq 'REAL' )
    {
    #$fmt_class .= $field_data > 0 ? " hi" : ""; # FIXME: move to field options
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    $data_fmt = type_format_human( $data_fmt, $fdes->{ 'TYPE' } ) unless des_get_attr( $fdes, 'WEB', $vtype, 'NO_HUMAN_FMT' );
    }
  elsif( $type_name eq 'UTIME' or $type_name eq 'DATE' )
    {
    return '&empty;' if $field_data == 0;
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    my $details = des_get_attr( $fdes, 'WEB', $vtype, 'DETAILS' );

    my $ud = $type_name eq 'UTIME' ? time() - $field_data : gm_julian_day(time()) - $field_data; # time delta
    if( $details )
      {
      #$details = 2 if uc $details eq 'AUTO' and $vtype eq 'GRID';
      my $sep;
      $sep = '<br>' unless $details % 2;

      $sep .= ' &nbsp; &Delta;' if $details == 1;
      $sep .= ' &nbsp; &lArr;'  if $details >= 3 and $ud  > 0;
      $sep .= ' &nbsp; &rArr;'  if $details >= 3 and $ud  < 0;
      $sep .= ' &nbsp; ='       if $details >= 3 and $ud == 0;
       
      my $diff;                                               
      if( $type_name eq 'UTIME' )
        {
        $diff = unix_time_diff_in_words_relative( $ud ) if $details <= 2;
        $diff = unix_time_diff_in_words_short( $ud )    if $details >= 3;
        }
      else
        {
        $diff = julian_date_diff_in_words_relative( $ud ) if $details <= 2;
        $diff = julian_date_diff_in_words( $ud )          if $details >= 3;
        }  
      
      $diff =~ s/([a-z]{2,})/\[~$1\]/gi; # translate
      $data_fmt .= " <span class=details-text>$sep $diff</span>";
      }
    
    if( $ud > 0 and des_get_attr( $fdes, 'WEB', $vtype, 'OVERDUE' ) )
      {
      $data_fmt = "<span class=warning>[~DUE]</span> " . $data_fmt;
      }
    
    }
  elsif( $type_name eq 'LINK' and $editable and de_web_profile()->allows( $fdes, 'UPDATE' ) )
    {
    my ( $linked_table, $linked_field ) = des_link_details( $fdes );
    my $ltdes = $core->describe( $linked_table );
    my $lfdes = des_field_des( $ltdes, $linked_field );

    my $linked_data = $core->read_field( $linked_table, $linked_field, $field_data );
    $data_fmt = $field_data > 0 ? type_format( $linked_data, $lfdes->{ 'TYPE' } ) : '&empty;';

    my $select_filter_name = des_get_attr( $fdes, 'WEB', 'SELECT_FILTER' );

    my $combo = des_get_attr( $fdes, qw( WEB COMBO ) );
    my $radio = des_get_attr( $fdes, qw( WEB RADIO ) );

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

    my @lfields = @{ des_fields_list_by_oper( $ltdes, 'READ', de_web_profile() ) };
    unshift @lfields, $linked_field;

    my %bfdes; # base/begin/origin field descriptions, indexed by field path
    my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
    my %basef; # base fields map, return base field NAME by field path

    de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

    my $lfields = join ',', '_ID', @lfields, values %basef;

    my $combo_orderby = des_get_attr( $fdes, qw( WEB COMBO ORDERBY ) ) || join( ',', @spf_fld );
    my $combo_select = $core->select( $linked_table, $lfields, { 'FILTER_NAME' => $select_filter_name, ORDER_BY => $combo_orderby } );


    my $combo_form_text;
    my $combo_form = new Web::Reactor::HTML::Form( $reo );
    
    $combo_form_text .= $combo_form->begin( NAME => $reo->create_uniq_id(), );
    $combo_form->state( 'UPDATE_RECORD_WITH_ID' => $id );

    my @combo_data;
    push @combo_data, { KEY => '*', VALUE => 0, LABEL => '&empty;' };
    while( my $hr = $core->fetch( $combo_select ) )
      {
      my @value = map { $hr->{ $_ } } @spf_fld;
      my $value = sprintf( $spf_fmt, @value );
      my $id    = $hr->{ '_ID' };
      push @combo_data, { KEY => '*', VALUE => $id, LABEL => $value };
      }

#print STDERR "**************************************************************: " . Dumper( \@combo_data );

    if( des_get_attr( $fdes, 'WEB', 'EDIT', 'MONO' ) )
      {
      $fmt_class .= " fmt-mono";
      }

    #$combo_form_text .= $combo_form->state(  NAME => '', VALUE => '' );
    $combo_form_text .= $combo_form->combo(  NAME     => "F:$fname", 
                                             CLASS    => $fmt_class, 
                                             DATA     => \@combo_data, 
                                             SELECTED => $field_data,
                                             RADIO    => $radio,
                                             
                                             SUBMIT_ON_CHANGE => 1,
                                             );

    $combo_form_text .= $combo_form->end();

    $data_fmt = $combo_form_text;
    }
  elsif( des_is_linked( $fdes ) or des_is_widelinked( $fdes ) )
    {
    my ( $linked_table, $linked_id, $linked_field );
    if( des_is_widelinked( $fdes ) ) 
      {
      ( $linked_table, $linked_id, $linked_field ) = type_widelink_parse2( $field_data );

      my $ltdes = $core->describe( $linked_table );
      if( $ltdes )
        {
        my $linked_table_label = des_table_label( $ltdes );
        if( $linked_field )
          {
          $data_fmt = $core->read_field( $linked_table, $linked_field, $linked_id );
          my $lfdes = des_field_des( $ltdes, $linked_field );
          $data_fmt  = de_web_format_field( $data_fmt, $lfdes, 'VIEW', { ID => $linked_id } );
          }
        else
          {
          $data_fmt = "[~Linked to a record from:] $linked_table_label";
          }  
        } # ltdes  
      else
        {
        $data_fmt = "&empty;";
        }  
      }
    else
      {
      ( $linked_table, $linked_field ) = des_link_details( $fdes );
      my $ldes = $core->describe( $linked_table );
      my ( $linked_field_x, $linked_field_x_des ) = des_field_des( $ldes, $linked_field )->expand_field_path();

      if( $field_data > 0 )
        {
        my $linked_field_x_data = $core->read_field( $linked_table, $linked_field_x, $field_data );
        $data_fmt = de_web_format_field( $linked_field_x_data, $linked_field_x_des, $vtype );
        }
      else
        {
        $data_fmt = "&empty;";
        }  
      }  
    }
  elsif( des_is_map( $fdes ) )
    {
    $data_fmt = join '', map { "* $_<br>" } @{ de_get_selected_map_names( $core, $fdes, $id ) };
    }
  elsif( des_is_backlinked( $fdes ) )
    {
    my ( $backlinked_table, $backlinked_field ) = des_backlink_details( $fdes );
    
    my $bltdes = $core->describe( $backlinked_table );
    my $linked_table_label = des_table_label( $bltdes );

    my $count = $field_data || $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
    $count = 'Unknown' if $count eq '';

    $data_fmt = qq( <b class=hi>$count</b> [~items] );
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
  
  my $table  =    shift;
  my $fields = uc shift;
  my $opt    =    shift || {};

  my $tdes = $core->describe( $table );

  my $ctrl_cb  = $opt->{ 'CTRL_CB'  };
  my $order_by = $opt->{ 'ORDER_BY' } || $tdes->{ '@' }{ 'ORDER_BY' } || '._ID DESC';
  my $sums     = $opt->{ 'SUMS'     };

  $fields = des_fields_list( $tdes ) if $fields eq '*';
  
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
    $text .= "<div class='fmt-right' colspan=$c>//$title</div>";
    }

  $text .= "<table class='$class' cellspacing=0 cellpadding=0>";
  
  $text .= "<tr class=grid-header>";
  
  $text .= "<td class='grid-header fmt-left'><img src=i/ctrl.svg></td>" if $ctrl_cb;

  for my $field ( @fields )
    {
    next if $field eq '_ID';
    
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';

    my $base_field = $bfdes->{ 'NAME' };

    my $blabel    = des_get_attr( $bfdes, qw( WEB GRID LABEL ) );
    my $label     = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = des_get_attr( $lfdes, qw( WEB GRID LABEL ) );
      $label .= "/$llabel";
      }

    $text .= "<td class='grid-header $fmt_class'>$label</td>";
    }
  $text .= "</tr>";

  my %sums;

  my $row_counter;
  while( my $row_data = $core->fetch( $select ) )
    {
    $sums{ '*' }++;
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

      my $lpassword = des_get_attr( $lfdes, 'PASSWORD' ) ? 1 : 0;

      my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

      my $data = $row_data->{ $field };
      my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };

      $sums{ $field } += $data if $sums and $type_name =~ /^(INT|REAL|TIME)$/;

      my ( $data_fmt, $fmt_class_fld ) = de_web_format_field( $data, $lfdes, 'GRID', { ID => $id, CORE => $core } );
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
    
  if( $sums )  
    {
    $text .= "<td class='grid-header fmt-left'>&sum; $sums{'*'}</td>";

    for my $field ( @fields )
      {
      next if $field eq '_ID';
      
      my $bfdes      = $bfdes{ $field };
      my $lfdes      = $lfdes{ $field };
      my $type_name  = $lfdes->{ 'TYPE' }{ 'NAME' };
      my $ltype_name = $lfdes->{ 'TYPE' }{ 'LNAME' };
      my $fmt_class  = $FMT_CLASSES{ $type_name } || 'fmt-left';

      my ( $data_fmt, $fmt_class_fld );
      if( $ltype_name =~ /^(BOOL)$/ )
        {
        ( $data_fmt, $fmt_class_fld ) = ( $sums{ $field } . ' of ' . $sums{'*'} );
        }
      else
        {  
        ( $data_fmt, $fmt_class_fld ) = $type_name =~ /^(INT|REAL|TIME)$/ ? de_web_format_field( $sums{ $field }, $lfdes, 'GRID' ) : ();
        }
      $text .= "<td class='grid-header $fmt_class'>$data_fmt</td>";
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
  
  my $table  =    shift;
  my $fields = uc shift;
  my $id     =    shift;
  my $opt    =    shift || {};

  my $ctrl_cb  = $opt->{ 'CTRL_CB'  };
  my $order_by = $opt->{ 'ORDER_BY' } || '._ID';

  my $tdes = $core->describe( $table );
  
  my @fields;
  if( $fields eq '*' )
    {
    @fields = @{ des_fields_list_by_oper( $tdes, 'READ', de_web_profile() ) };
    }
  else
    {
    @fields = ref( $fields ) eq 'ARRAY' ? @$fields : split /\s*,\s*/, $fields;
    }  
  
  
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

  $text .= "<div class='record-table'>";
  $text .= "<div class='view-header view-sep record-sep fmt-center'>$title</div>";

  my $record_first = 1;
  for my $field ( @fields )
    {
    next if $field eq '_ID';

    my $bfdes      = $bfdes{ $field };
    my $lfdes      = $lfdes{ $field };
    my $type_name  = $lfdes->{ 'TYPE' }{ 'NAME'  };
    my $type_lname = $lfdes->{ 'TYPE' }{ 'LNAME' };

    my $lpassword = des_get_attr( $lfdes, 'PASSWORD' ) ? 1 : 0;

    my $label     = des_get_attr( $bfdes, qw( WEB VIEW LABEL ) );

    my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

    my $data      = $row_data->{ $field };
    my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
    my ( $data_fmt, $data_fmt_class )  = de_web_format_field( $data, $lfdes, 'VIEW', { ID => $id } );
    my $data_ctrl;
    my $field_details;
    my $no_layout_ctrls = 0;

    my $overflow  = des_get_attr( $bfdes, qw( WEB VIEW OVERFLOW ) );
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

    my $divider = des_get_attr( $bfdes, 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='view-divider view-sep record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

    my $data_layout = $no_layout_ctrls ? $data_fmt : html_layout_2lr( $data_fmt, $data_ctrl, '<==1>' );
    my $base_field_class = lc "css_view_class_$base_field";

    my $record_first_class = 'record-first' if $record_first;
    $record_first = 0;
    $text .= "<div class='record-field-value'>
                <div class='view-field record-field $record_first_class $base_field_class                ' >$label</div>
                <div class='view-value record-value $record_first_class $base_field_class $data_fmt_class' >$data_layout</div>
              </div>";
    if( $field_details )
      {
      $text .= "<div class='view-details record-details'>$field_details</div>";
      }
    }
  $text .= "</div>";

}

# possible alternatives to 'master': 'leadeing'
sub de_master_record_view
{
  my $reo  = shift;

  my $core = $reo->de_connect();

  my $master_record_table = $reo->param( 'MASTER_RECORD_TABLE' );
  my $master_record_id    = $reo->param( 'MASTER_RECORD_ID'    );

  if( ! $master_record_table or ! $master_record_id )
    {
    ( $master_record_table, $master_record_id ) = split /:/, $reo->param( 'MASTER_RECORD' );
    }

  return undef unless $master_record_table and $master_record_id;

  my $tdes = $core->describe( $master_record_table );
  my $sdes = des_table_des( $tdes ); # table "Self" description
  my $table_label = des_table_label( $tdes );
  my $master_fields = uc des_get_attr( $sdes, qw( WEB MASTER_FIELDS ) ) or return undef;

  #return de_data_grid( $core, $linked_table, $master_fields, { FILTER => { '_ID' => $link_id }, LIMIT => 1, CLASS => 'grid view record', TITLE => "[~Master record from] $linked_table_label" } ) if $master_fields;
  my $title = des_table_s( $tdes ) || "[~Master record from] $table_label";
  return "<p>" . de_data_view( $core, $master_record_table, $master_fields, $master_record_id, { CLASS => 'view record', TITLE => $title } );
}

sub de_progress_bar
{
  my $value = shift;
  my $width = shift; # screen width in em (letters)

  my $prc;
  my $val;
  ( $prc, $val ) = ( 100*$1/$2, " ($value)" ) if ! $prc and $value =~ /(\d+)\/(\d+)/ and $1 < $2 and $2 > 0; # allow string with xx/nn
  $prc = $1        if ! $prc and $value =~ /(\d+(\.\d+)?)%?/; # or string with xx.nn%
  $prc = $value    if ! $prc; # assumed a number

  $prc =   0 if $prc <   0 or ! $prc;
  $prc = 100 if $prc > 100;
  
  my $p1  = sprintf( "%.1f%%", $prc ) . $val if $prc < 50;
  my $p2  = sprintf( "%.1f%%", $prc ) . $val if $prc > 50;
  
  my $pn  = 100 - $prc;

  my $d1 = " ;display: none; " if $prc ==   0;
  my $d2 = " ;display: none; " if $prc == 100;

  # $p2 = "Complete" if $prc == 100;
  
  my $wd = " ;width: ${width}em; " if $width =~ /^\d+$/ and $width > 0;
  
  return "<div class=progress-div style='$wd'><div class=progress-bar style='width: $prc%; $d1'>$p2</div><div class=progress-empty style='width: $pn%; $d2'>$p1</div></div>";
}

1;
