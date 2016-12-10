##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::View;
use strict;
use Data::Dumper;
use Exception::Sink;
use Data::Tools::Time;

use Decor::Shared::Types;

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
 
  my @res_fields;
  
  for( @$fields )
    {
    # resolve fields
    if( /\./ )
      {
      ( $bfdes->{ $_ }, $lfdes->{ $_ } ) = $tdes->resolve_path( $_ );
      }
    else
      {  
      my $fdes    = $tdes->{ 'FIELD' }{ $_ };
      if( $fdes->is_linked() )
        {
        my $ld;
        ( $_, $ld ) = $fdes->expand_field_path();
        $lfdes->{ $_ } = $ld;
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
  my $data  =    shift;
  my $fdes  =    shift;
  my $vtype = uc shift;
  my $opts  =    shift;

  my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };

  my $data_fmt;
  my $fmt_class;

  if( $type_name eq 'CHAR' )
    {
    $data_fmt = type_format( $data, $fdes->{ 'TYPE' } );

    my $maxlen = $fdes->get_attr( 'WEB', $vtype, 'MAXLEN' );
    if( $maxlen )
      {

      $maxlen = 16 if $maxlen <   0;
      $maxlen = 16 if $maxlen > 256;
      if( length( $data_fmt ) > $maxlen )
        {
        my $cut_len = int( ( $maxlen - 3 ) / 2 );
        $data_fmt = substr( $data_fmt, 0, $cut_len ) . ' &hellip; ' . substr( $data_fmt, - $cut_len );
        }
      }
    if( $fdes->get_attr( 'WEB', $vtype, 'MAXLEN' ) )
      {
      $fmt_class .= " fmt-mono";
      }
    }
  elsif( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
    {
    $data_fmt = $data > 0 ? '[&radic;]' : '[&nbsp;]';
    }
  elsif( $type_name eq 'UTIME' )
    {
    return '&laquo;empty&raquo;' if $data == 0;
    $data_fmt = type_format( $data, $fdes->{ 'TYPE' } );
    my $details = $fdes->get_attr( 'WEB', $vtype, 'DETAILS' );
    
    if( $details )
      {
      my $sep  = $details > 1 ? '<br>' : '&Delta;';
      my $diff = unix_time_diff_in_words_relative( time() - $data );
      $data_fmt .= " <span class=details-text>$sep $diff</span>";
      }
    }
  else
    {
    $data_fmt = type_format( $data, $fdes->{ 'TYPE' } );
    }  


  return wantarray ? ( $data_fmt, $fmt_class ) : $data_fmt;
}

1;
