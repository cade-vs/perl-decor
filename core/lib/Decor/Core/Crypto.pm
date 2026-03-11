##############################################################################
##
##  DECOR application machinery core
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Crypto;
use strict;

use Exporter;
BEGIN
{
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_crypt
                de_decrypt

                );
}

use Data::Lock qw( dlock dunlock );
use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;
use Crypt::PK::RSA;
use MIME::Base64 qw( encode_base64 decode_base64 );

use Decor::Shared::Types;
use Decor::Shared::Utils;
use Decor::Shared::Config;
use Decor::Core::Env;
use Decor::Core::Log;

$Data::Dumper::Sortkeys = 1;

### PRIVATE ##################################################################

my $VERSION = '1.01';

my %RSAO;

sub __key_fn
{
  my $key_name = shift;
  my $private  = shift;
  
  my $app_dir = de_app_dir();

  my $sx = $private ? 'pvt' : 'pub';
  
  return "$app_dir/keys/$key_name-$sx.pem";
}

sub __get_rsa
{
  my $key_name = shift;
  my $private  = shift;

  my $sx = $private ? 'pvt' : 'pub';

  return $RSAO{ $sx }{ $key_name } if exists $RSAO{ $sx }{ $key_name };

  my $rsa = Crypt::PK::RSA->new( __key_fn( $key_name, $private ) );

  $RSAO{ $sx }{ $key_name } = $rsa;
  
  return $rsa;
}

sub __get_rsa_pub { return __get_rsa( shift(), 0 ); }
sub __get_rsa_pvt { return __get_rsa( shift(), 1 ); }

### PUBLIC ###################################################################

sub de_crypt
{
  my $key_name = shift;
  my $data     = shift;
  
  return encode_base64( __get_rsa_pub( $key_name )->encrypt( $data, 'oaep', 'SHA256' ) );
}

sub de_decrypt
{
  my $key_name = shift;
  my $data     = shift;
  
  return __get_rsa_pvt( $key_name )->decrypt( decode_base64( $data ), 'oaep', 'SHA256' );
}


### EOF ######################################################################
1;

__DATA__

use strict;
use warnings;

# --- Key generation ---
my $pk = Crypt::PK::RSA->new;
$pk->generate_key( 256, 65537 );  # 256 bytes = 2048 bits

my $priv_pem = $pk->export_key_pem( 'private' );
my $pub_pem  = $pk->export_key_pem( 'public'  );

print "Private key:\n$priv_pem\n";
print "Public key:\n$pub_pem\n";

# --- Encryption (OAEP, SHA256) ---
my $pub = Crypt::PK::RSA->new( \$pub_pem );
my $ciphertext = $pub->encrypt( "secret message", 'oaep', 'SHA256' );
print "Encrypted: ", encode_base64( $ciphertext ), "\n";

# --- Decryption ---
my $priv = Crypt::PK::RSA->new( \$priv_pem );
my $plaintext = $priv->decrypt( $ciphertext, 'oaep', 'SHA256' );
print "Decrypted: $plaintext\n";

# --- Signing (PSS, SHA256) ---
my $message = "sign this";
my $sig = $priv->sign_message( $message, 'SHA256', 'pss' );
print "Signature: ", encode_base64( $sig ), "\n";

# --- Verification ---
if( $pub->verify_message( $sig, $message, 'SHA256', 'pss' ) )
  {
  print "Signature OK\n";
  }
else
  {
  print "Signature FAILED\n";
  }

# --- Save/load keys from files ---
open my $fh, '>', 'private.pem' or die $!;
print $fh $priv_pem;
close $fh;

my $loaded = Crypt::PK::RSA->new( 'private.pem' );
print "Loaded key size: ", $loaded->key_size * 8, " bits\n";
