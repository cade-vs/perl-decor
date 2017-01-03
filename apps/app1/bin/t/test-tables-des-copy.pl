#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );

use Time::HR;

use Data::Dumper;
use Data::Tools;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;
use Decor::Core::DB::Record;

use Data::Lock qw( dlock dunlock );

use Storable qw( dclone );
use Clone qw( clone );

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $profile = new Decor::Core::Profile;
$profile->set_groups( 999, 33..44 );

my $t = gethrtime();
for( 1..1_000 )
{
  my $des = describe_table( 'test1' );
  #my $copy = dclone( $des );
  #my $copy = clone( $des );
  my $copy = des_copy( $des );
}
$t = ( gethrtime() - $t ) / 1_000_000_000;
my $ps = 1_000 / $t;
print "$t secs, $ps per second\n";


print Dumper( describe_table( 'test1' ) );
print Dumper( des_copy( describe_table( 'test1' ) ) );

print "$t secs, $ps per second\n";



sub des_copy
{
  my $des = shift;
  
  my $new = clone( $des );

  $new->{ '@' }{ 'GRANT' } = replace_grant_deny( $des->{ '@' }{ 'GRANT' } );
  $new->{ '@' }{ 'DENY'  } = replace_grant_deny( $des->{ '@' }{ 'DENY'  } );
  delete $new->{ 'INDEX' };

  for my $field ( @{ $new->{ '@' }{ '_FIELDS_LIST' } } )
    {
    my $hrd = $des->{ 'FIELD' }{ $field };
    my $hrn = $new->{ 'FIELD' }{ $field };
    #dunlock $hr;
    #dunlock $hr->{ 'DENY'  };
    $hrn->{ 'GRANT' } = replace_grant_deny( $hrd->{ 'GRANT' } );
    $hrn->{ 'DENY'  } = replace_grant_deny( $hrd->{ 'DENY'  } );
    delete $hrn->{ 'DEBUG::ORIGIN' };
    }

  return $new;
}

=pod
sub des_copy2
{
  my $des = shift;
  
  my %new;
  
  $new{ '@' } = { %{ $des->{ '@' } } };
  $new{ '@' }{ 'GRANT' } = replace_grant_deny( $des->{ '@' }{ 'GRANT' } );
  $new{ '@' }{ 'DENY'  } = replace_grant_deny( $des->{ '@' }{ 'DENY'  } );

  for my $field ( @{ $new{ '@' }{ '_FIELDS_LIST' } } )
    {
    $new{ 'FIELD' }{ $field } = { %{ $des->{ 'FIELD' }{ $field } } };
    $new{ 'FIELD' }{ $field }{ 'GRANT' } = replace_grant_deny( $des->{ 'FIELD' }{ $field }{ 'GRANT' } );
    $new{ 'FIELD' }{ $field }{ 'DENY'  } = replace_grant_deny( $des->{ 'FIELD' }{ $field }{ 'DENY'  } );
    }
  
  return \%new;
}
=cut

sub replace_grant_deny
{
  my $grant_deny = shift;
  my %new;
  
  while( my ( $k, $v ) = each %$grant_deny )
    {
    $new{ $k } = $profile->__check_access_tree( $k, $grant_deny );
    }
    
  return \%new;  
}
