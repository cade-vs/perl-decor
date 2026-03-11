package decor::tables::de_pwd;
use strict;
use Data::Tools;

use Decor::Core::Subs::Env;
use Decor::Core::Methods;
use Decor::Core::Crypto;

sub on_recalc
{
  my $r = shift;

  my $pass  = $r->read( 'PASSWORD'  );
  my $pass1 = $r->read( 'PASSWORD1' );
  my $pass2 = $r->read( 'PASSWORD2' );

  # TODO: decrypt passwords here
  
  $pass  = de_decrypt( 'pass', $pass  ) if $pass;
  $pass1 = de_decrypt( 'pass', $pass1 ) if $pass1;
  $pass2 = de_decrypt( 'pass', $pass2 ) if $pass2;

  my $user = subs_get_current_user();

  my $errors;

  if( $pass !~ /\S/ )
    {
    $r->method_add_field_error( 'PASSWORD',  'Empty password' ) ;
    $errors++;
    }
  elsif( ! $user->verify_password( $pass ) )
    {
    $r->method_add_field_error( 'PASSWORD',  'Wrong password' ) ;
    $errors++;
    }

  if( $pass1 !~ /\S/ )
    {
    $r->method_add_field_error( 'PASSWORD1', 'Empty password' ) ;
    $errors++;
    }
  elsif( str_password_strength( $pass1 ) < 33 )
    {
    $r->method_add_field_error( 'PASSWORD1', 'Password is too weak' ) ;
    $errors++;
    }

  if( $pass2 !~ /\S/ )
    {
    $r->method_add_field_error( 'PASSWORD2', 'Empty password' ) ;
    $errors++;
    }
  elsif( str_password_strength( $pass2 ) < 33 )
    {
    $r->method_add_field_error( 'PASSWORD2', 'Password is too weak' ) ;
    $errors++;
    }

  if( $pass1 =~ /\S/ and $pass2 =~ /\S/ and $pass1 ne $pass2 )
    {
    $r->method_add_field_error( 'PASSWORD1', 'Passwords do not match' ) ;
    $r->method_add_field_error( 'PASSWORD2', 'Passwords do not match' ) ;
    $errors++;
    }

  return ( $errors, $pass1 );
}

sub on_insert
{
  my $r = shift;
  
  my ( $errors, $pass1 ) = on_recalc( $r );
  
  return if $errors;

  my $user = subs_get_current_user();
  $user->set_password( $pass1 );
  $user->save();
  
  # TODO: add virtual fields into description and handling
  $r->write( 'PASSWORD'  => '******' );
  $r->write( 'PASSWORD1' => '******' );
  $r->write( 'PASSWORD2' => '******' );
}

sub on_update
{
  my $r = shift;
  
}


sub __recalc_password_check
{
  my $r = shift;

}

1;
