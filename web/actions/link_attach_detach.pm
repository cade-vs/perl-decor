##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::link_attach_detach;
use strict;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Web::Grid;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE'  );
  my $fname  = $reo->param( 'FNAME'  );
  my $id     = $reo->param( 'ID'     );
  my $pa_id  = $reo->param( 'PA_ID'  ); # parent record id
  my $value  = $reo->param( 'VALUE'  );

  my $core = $reo->de_connect();

  my $new_value = $value > 0 ? 0 : $pa_id;

  print STDERR "\n" x 10;
  print STDERR "$core->update( $table, { $fname => $new_value }, { ID => $id } )\n";
  print STDERR "de_web_grid_backlink_detach_attach_icon( $reo, $core, $table, $fname, $id, $pa_id, $value, )";
  print STDERR "\n" x 10;

  my $res = $core->update( $table, { $fname => $new_value }, { ID => $id } );

  $text .= de_web_grid_backlink_detach_attach_icon( $reo, $core, $table, $fname, $id, $pa_id, $new_value, );
  
  return $text;
}

1;
