package decor::tables::todo;
use strict;

sub on_recalc_insert
{
  my $r = shift;

  $r->write( 'CTIME' => time() );
}

sub on_recalc
{
  my $r = shift;

  $r->write( 'MTIME' => time() );
  
  # $r->method_add_field_error( 'MTIME', "Not allowed on ODD seconds :)" ) if time() % 2;
  
}

sub on_insert
{
  my $r = shift;
  
  on_recalc_insert( $r );
}

sub on_update
{
  my $r = shift;
  
  on_recalc( $r );
}

1;
