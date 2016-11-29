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

use Decor::Shared::Types;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_format_field

                );


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
    my $maxlen = $fdes->get_attr( 'WEB', $vtype, 'MAXLEN' );
    if( $maxlen )
      {
      $maxlen = 16 if $maxlen <   0;
      $maxlen = 16 if $maxlen > 256;
      if( length( $data ) > $maxlen )
        {
        my $cut_len = int( ( $maxlen - 3 ) / 2 );
        $data_fmt = substr( $data, 0, $cut_len ) . ' &hellip; ' . substr( $data, - $cut_len );
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
    }
  else
    {
    $data_fmt = type_format( $data, $fdes->{ 'TYPE' } );
    }  


  return wantarray ? ( $data_fmt, $fmt_class ) : $data_fmt;
}

1;
