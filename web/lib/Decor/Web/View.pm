##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
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
use Data::Tools::Time;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_web_expand_resolve_fields_in_place
                de_web_format_field

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
        my $xf;
        my $ldes;
        ( $_, $ldes ) = $fdes->expand_field_path();
        $lfdes->{ $_ } = $ldes;
        $basef->{ $_ } = $fdes->{ 'NAME' };
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

sub de_web_format_field
{
  my $field_data =    shift;
  my $fdes       =    shift;
  my $vtype      = uc shift;
  my $opts       =    shift;
  
  my $reo  = $opts->{ 'REO'  };
  my $core = $opts->{ 'CORE' };
  my $id   = $opts->{ 'ID' };

  my $table = $fdes->table();
  my $fname = $fdes->name();
  my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };

  my $data_fmt;
  my $fmt_class;

  my $password = ( $fdes->get_attr( 'PASSWORD' ) or $fname =~ /^PWD_/ ) ? 1 : 0;

  if( $type_name eq 'CHAR' )
    {
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );

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
      $data_fmt = "<div class=vframe><a reactor_new_href=?_an=set_val&table=$table&fname=$fname&id=$id&value=$new_val&vtype=$vtype>$data_fmt</a></div>";
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
      my $sep  = $details > 1 ? '<br>' : '&Delta;';
      my $diff = unix_time_diff_in_words_relative( time() - $field_data );
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
      my $sep  = $details > 1 ? '<br>' : '&Delta;';
      my $diff = julian_date_diff_in_words_relative( gm_julian_day(time()) - $field_data );
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

    my $vframe_id = 'VFRGE_' . $reo->html_new_id();

    my $combo_text;
    $combo_text .= "<a class=grid-link-select-option reactor_new_href=?_an=set_val&table=$table&fname=$fname&id=$id&value=0&vtype=$vtype data-vframe-target=$vframe_id>&empty;</a>";
    while( my $hr = $core->fetch( $combo_select ) )
      {
      my @value = map { $hr->{ $_ } } @spf_fld;
      my $value = sprintf( $spf_fmt, @value );
      my $key   = $hr->{ '_ID' };
      $combo_text .= "<a class=grid-link-select-option reactor_new_href=?_an=set_val&table=$table&fname=$fname&id=$id&value=$key&vtype=$vtype data-vframe-target=$vframe_id>$value</a>";
      }

    if( $fdes->get_attr( 'WEB', 'EDIT', 'MONO' ) )
      {
      $fmt_class .= " fmt-mono";
      }

    my $popup_layer_html;
    ( $data_fmt, $popup_layer_html ) = de_html_popup( $reo, $data_fmt, $combo_text );
    $data_fmt = "<div class=vframe id=$vframe_id style='width: 100%;'><div class=grid-link-select>$data_fmt</div>$popup_layer_html</div>";
    }
  else
    {
    $data_fmt = type_format( $field_data, $fdes->{ 'TYPE' } );
    }

  return wantarray ? ( $data_fmt, ' ' . $fmt_class ) : $data_fmt;
}

1;
