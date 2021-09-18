##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Methods;
use strict;

use Data::Tools;
use Exception::Sink;

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::DB::Record;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                find_user_by_name
                create_user
                set_user_pass

                );

sub find_user_by_name
{
  my $name = shift;
  
  my $rec = new Decor::Core::DB::Record;
  return $rec if $rec->select_first1( 'DE_USERS', 'NAME = ?', { BIND => [ $name ], LOCK => 1 } );
  return undef;
}

sub create_user
{
  my $user   = shift;
  my $pass   = shift;
  my $prig   = shift; # primary group, or undef to private instead
  my $groups = shift || [];
  
  # create private group record
  my $grp_rec = new Decor::Core::DB::Record;
  $grp_rec->create( 'DE_GROUPS' );
  $grp_rec->write( 
                    NAME      => $user, 
                  );
  $grp_rec->save();

  # create user record
  my $user_rec = new Decor::Core::DB::Record;
  $user_rec->create( 'DE_USERS' );
  
  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    NAME      => $user, 
                    ACTIVE    => 1,
                  );

  # setup password if specified, otherwise user will not be able to login
  if( $pass ne '' )
    {
    my $user_salt     = create_random_id( 128 );
    my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

    $user_rec->write( 
                      PASS      => $user_pass_hex,
                      PASS_SALT => $user_salt,
                    );
    }
  
  $prig ||= $grp_rec->id();
  
  $user_rec->write( 'PRIMARY_GROUP' => $prig          );
  $user_rec->write( 'PRIVATE_GROUP' => $grp_rec->id() );
  
  $user_rec->save();

  # attach given groups
  my $dio = new Decor::Core::DB::IO;

  my @groups = list_uniq( $grp_rec->id(), $prig, @$groups );

  my $user_id = $user_rec->id();
  for my $group ( @groups )
    {
    next if $dio->read_first1_hashref( 'DE_USER_GROUP_MAP', 'USR = ? AND GRP = ?', { BIND => [ $user_id, $group ] } );
    my $rc = $dio->insert( 'DE_USER_GROUP_MAP', { USR => $user_id, GRP => $group } );
    }
  
  return $user_rec;
}

sub set_user_pass
{
  my $user = shift;
  my $pass = shift;
  
  my $user_rec = ref( $user ) eq 'Decor::Core::DB::Record' ? $user : find_user_by_name( $user );
  
  return undef unless $user_rec;
  return undef unless $pass ne '';

  my $user_salt     = create_random_id( 128 );
  my $user_pass_hex = de_password_salt_hash( $pass, $user_salt ); 

  $user_rec->write( 
                    PASS      => $user_pass_hex,
                    PASS_SALT => $user_salt,
                  );
  
  return 1;                
}


### EOF ######################################################################
1;
