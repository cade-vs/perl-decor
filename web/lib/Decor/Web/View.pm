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

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_format_field

                );


sub de_web_format_field
{
  my $data = shift;
  my $fdes = shift;
  my $opts = shift;

  my $fmt_data = $data;

  if( $type_name eq 'CHAR' )
    {
    if( $field_options =~ /grid-len=(\d+)/ )
      {
      my $gl = $1;
      $gl = 16 if $gl <   0;
      $gl = 16 if $gl > 256;
      if( length( $data ) > $gl )
        {
        my $cut_len = int( ( $gl - 3 ) / 2 );
        $data_format = substr( $data, 0, $cut_len ) . ' ... ' . substr( $data, - $cut_len );
        }
      }
    if( $field_options =~ /grid-mono/ )
      {
      $fmt_class .= " fmt-mono";
      }
    }
  elsif( $type_name eq 'CHAR' )


  return $fmt_data;
}

1;
