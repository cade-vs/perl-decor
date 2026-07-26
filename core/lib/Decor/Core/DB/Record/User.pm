##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record::User;
use strict;

use Crypt::Argon2 qw( argon2id_pass argon2_verify );

use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Exception::Sink;
use Data::Tools;

use parent 'Decor::Core::DB::Record';

### DE_USERS api interface ###################################################

sub get_primary_group
{
  my $self   = shift;

  return $self->read( 'PRIMARY_GROUP' );
}

sub get_private_group
{
  my $self   = shift;

  return $self->read( 'PRIVATE_GROUP' );
}

sub get_groups
{
  my $self   = shift;

  my $io = new Decor::Core::DB::IO;
  return $io->read_all_fields( 'DE_USER_GROUP_MAP', 'GRP', 'USR = ?', { BIND => [ $self->id() ] } );
}

sub has_group
{
  my $self   = shift;
  
  return exists $self->get_groups()->{ shift() };
}

sub is_active
{
  my $self   = shift;

  return $self->read( 'ACTIVE' ) > 0;
}

sub is_disabled
{
  my $self   = shift;

  return $self->read( 'DISABLED' ) > 0;
}

sub set_password
{
  my $self   = shift;
  my $pass   = shift;
  my $opt    = shift || {}; # { LABEL => ..., XTIME => ... }

  # Hash a password (argon2 embeds its own salt)
  my $salt    = create_random_id( 16 );
  my $encoded = argon2id_pass( $pass, $salt, 32, '32M', 1, 32 );

  my $label = $opt->{ 'LABEL' } || 'PRIMARY';
  my $xtime = $opt->{ 'XTIME' } || 0;

  # store the password as a PASSWORD credential in DE_USER_CREDS;
  # keep one row per (USR,LABEL): drop the old one, then insert
  my $io = new Decor::Core::DB::IO;
  $io->delete( 'DE_USER_CREDS', 'USR = ? AND KIND = ? AND LABEL = ?',
               { BIND => [ $self->id(), 'PASSWORD', $label ] } );
  $io->insert( 'DE_USER_CREDS', {
                 USR    => $self->id(),
                 KIND   => 'PASSWORD',
                 LABEL  => $label,
                 SECRET => $encoded,
                 SALT   => $salt,   # not needed for argon2, kept for reference
                 ACTIVE => 1,
                 XTIME  => $xtime,
               } );

  return 1;
}

sub verify_password
{
  my $self   = shift;
  my $pass   = shift;

  my $now = time();

  # try every active, non-expired PASSWORD credential for this user
  my $cred_rec = new Decor::Core::DB::Record;
  $cred_rec->select( 'DE_USER_CREDS',
                     'USR = ? AND KIND = ? AND ACTIVE = ? AND DISABLED = ?',
                     { BIND => [ $self->id(), 'PASSWORD', 1, 0 ] } );
  while( $cred_rec->next() )
    {
    my $xtime = $cred_rec->read( 'XTIME' );
    next if $xtime > 0 and $xtime < $now;                    # this password expired
    next unless argon2_verify( $cred_rec->read( 'SECRET' ), $pass );

    # matched -- stamp last-used, clear fail counter
    $cred_rec->write( 'LAST_USED_TIME' => $now, 'FAIL_COUNT' => 0 );
    $cred_rec->save();
    $cred_rec->finish();
    return 1;
    }
  $cred_rec->finish();

  return 0;
}

# true only if the user has NO still-valid password credential
sub password_expired
{
  my $self = shift;

  my $now = time();

  my $cred_rec = new Decor::Core::DB::Record;
  $cred_rec->select( 'DE_USER_CREDS',
                     'USR = ? AND KIND = ? AND ACTIVE = ? AND DISABLED = ?',
                     { BIND => [ $self->id(), 'PASSWORD', 1, 0 ] } );
  while( $cred_rec->next() )
    {
    my $xtime = $cred_rec->read( 'XTIME' );
    next if $xtime > 0 and $xtime < $now;
    $cred_rec->finish();
    return 0;   # at least one valid password exists
    }
  $cred_rec->finish();

  return 1;
}

# certificate login: match an active, non-expired CERTIFICATE credential by fingerprint
sub verify_certificate
{
  my $self = shift;
  my $fp   = shift; # fingerprint presented by the client

  return 0 if $fp eq '';

  my $now = time();
  my $cred_rec = new Decor::Core::DB::Record;
  $cred_rec->select( 'DE_USER_CREDS',
                     'USR = ? AND KIND = ? AND CERT_FP = ? AND ACTIVE = ? AND DISABLED = ?',
                     { BIND => [ $self->id(), 'CERTIFICATE', $fp, 1, 0 ] } );
  while( $cred_rec->next() )
    {
    my $xtime = $cred_rec->read( 'XTIME' );
    next if $xtime > 0 and $xtime < $now;
    $cred_rec->write( 'LAST_USED_TIME' => $now );
    $cred_rec->save();
    $cred_rec->finish();
    return 1;
    }
  $cred_rec->finish();

  return 0;
}

### EOF ######################################################################
1;
