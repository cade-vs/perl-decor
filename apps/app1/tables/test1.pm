package decor::tables::test1;
use strict;
use cade::tools;

use Data::Dumper;

sub on_recalc
{
  my $r = shift;

  my $sum;

  $sum += $_ for $r->read( qw( AMOUNT1 AMOUNT2 AMOUNT3 ) );
  $r->write( AMOUNT4 => $sum );
  $r->write( CTIME   => time() );
  
#  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be less than 100' ) if $sum < 100;
#  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be above 500' ) if $sum > 500;
#  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be above 500' ) if $sum > 500;

#  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;
#  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;
#  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;

  print Dumper( 'RECALC-'x10, $r );

  my $cc = $r->edit_cache_get();
  my $ccr = ++$cc->{ 'TEST_EDIT_CACHE_COUNT' };

  #$r->read( 'AMOUNT1.ASD' );

  $r->write( DES => $ccr );
  
  my $sr = $r->select_backlinked_records( 'BACKREF' );
  while( $sr->next() )
    {
    print Dumper( 'SIBLING-'x10, $sr );
    }

  my $wh = $r->read_widelink( 'TEST_WLINK' );
  print Dumper( 'WIDELINK-'x10, $wh );
  
  #$r->write_widelink( 'TEST_WLINK', 'MOTEN', 10030, 'PEND' );
}

sub on_test
{
  print "test";
}

sub on_more
{
  print "more test";
}


sub on_do_date_test
{
  my $r = shift;
  
  $r->write( 'DATE_TEST' => 2345678 );
  
  my $ff = $r->form_gen_data( 'test' );
  $r->return_file_text( "<h1>All is fine when fine all</h1><h2>$ff</h2>", 'html' );
}

sub on_fetch
{
  print Dumper( \@_ );
  
  my $hr = shift;
  
  $hr->{ 'AMOUNT4' } *= 67;
}

sub on_insert
{
  my $r = shift;
  
  my $cc = $r->edit_cache_get();
  my $ccr = $cc->{ 'TEST_EDIT_CACHE_COUNT' }++;
  
  $r->return_file_text( "<h1>Insert processed fine, here is a cookie:</h1><h2>".rand(137137137)."</h2> cache($ccr)", 'html' );
}

sub on_update
{
  my $r = shift;

  my $wh = $r->write_widelink( 'TEST_WLINK', 'MOTEN', 10030, 'PEND' );
  
  #$r->return_file_text( "<h1>Insert processed fine, here is a cookie:</h1><h2>".rand(137137137)."</h2>", 'html' );
}


sub on_do_post_insert11
{
  my $r = shift;
  
  $r->return_file_text( "<h1>Post Insert Here</h1>", 'html' );
}

sub on_do_post_update22
{
  my $r = shift;
  
  $r->return_file_text( "<h1>Post Insert Here</h1>", 'html' );
}

sub on_do_standalone
{
  my $r = shift;
  
  $r->return_file_text( "<h1>STANDALONE DO! :)</h1>", 'html' );
}

1;
