##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::filesys;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

my %FMT_CLASSES = (
                  'CHAR'  => 'fmt-left',
                  'DATE'  => 'fmt-left',
                  'TIME'  => 'fmt-left',
                  'UTIME' => 'fmt-left',

                  'INT'   => 'fmt-right fmt-mono',
                  'REAL'  => 'fmt-right fmt-mono',
                  );

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $text;

  my $grid_mode  = $reo->param( 'GRID_MODE'  ) || 'NORMAL';

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $table    = $reo->param( 'TABLE'  );
  my $path_dir = $reo->param( 'PATH_DIR' );
  my $path_id  = $reo->param( 'PATH_ID'  );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des();

  my $table_label = $tdes->get_label();

  $reo->ps_path_add( 'filesys', qq( [~List files from] "<b>$table_label</b>" ) );

  return "<#e_internal>" unless $tdes;


  if( $root_dir and $root_id <= 0 )
    {
    $root_id = __resolve_path( $core, $table, $root_dir );
    }
  $root_id = 0 if $root_id < 0;

  # TODO: implementation
  
  return $text;
}


sub __resolve_path
{
  $core     = shift;
  $table    = shift;
  $root_dir = shift;
  
  return 0;
}  

1;
