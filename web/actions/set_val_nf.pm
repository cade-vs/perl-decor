##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::set_val_nf;
use strict;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in(); # FIXME: always?

  my $table  = $reo->param( 'TABLE' );
  my $fname  = $reo->param( 'FNAME' );
  my $id     = $reo->param( 'ID'    );
  my $value  = $reo->param( 'VALUE' );

  my $core = $reo->de_connect();

  my $res = $core->update( $table, { $fname => $value }, { ID => $id } );

  return $reo->forward_back();
}

1;
