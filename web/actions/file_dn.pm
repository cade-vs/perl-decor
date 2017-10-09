##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::file_dn;
use strict;
use Data::Dumper;
use File::Temp qw( tempfile );

use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $core = $reo->de_connect();

  my $file = $core->select_first1_by_id( $table, '*', $id );
  return "<#e_access>" unless $file;
  
  my $mime     = $file->{ 'MIME' } || 'application/octet-stream';

  my $fh = tempfile( DIR => '/tmp/', SUFFIX => '.tmp', UNLINK => 1 );
####  open( $fh, '>', '/tmp/asdasdasdasdasdasd' );

  $core->file_load( $fh, $table, $id );
  seek( $fh, 0, 0 );

  return $reo->render_data( undef, $mime, FH => $fh );
}

1;
