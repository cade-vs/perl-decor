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

use Time::HiRes qw( time );

use Data::Dumper;
use Decor::Core::Boot;
use Decor::Core::Debug;
use Decor::Core::Loader::Table;
use Decor::Shared::Describe;
use Decor::Core::Profile;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_debug_inc();

de_boot( APP_NAME => 'app1' );

my $des = load_table( 'test1' );
$des    = load_table( 'test1' ); # second load is a cache hit

print STDERR '='x80;

print STDERR Dumper( $des );
print STDERR Dumper( des_fields_list( 'test1' ) );
#print STDERR Dumper( des_table_des( 'test1' ) );

my $profile = new Decor::Core::Profile;
$profile->add_groups( qw( 2 3 4 5 1342 ) );
print STDERR Dumper( $profile );

print "-------------------------------------------------access test-----\n";

$profile->set_groups( qw( 2 6 4 5 1342 ) );
print "YES ACCESS PROFILE\n" if $profile->check_access_table( 'UPDATE', 'TEST1' );


my $s = time();

my $c;
for( 1..200_000 )
  {
  $c++ if $profile->check_access_table( 'UPDATE', 'TEST1' );
  }

my $d = time() - $s;

print $d;
print " secs c[$c]\n", Dumper( $profile->{ 'VAR' }, $profile->{ 'CACHE' } );

=pod
my $s = gethrtime();

my $gr = $TMP_DES{ 'test1' }{ '@' }{ 'update' };
for( 1..1000_000 )
  {
  print "YES ACCESS HASH\n" if exists $TMP_PROFILE{ $gr } and $TMP_PROFILE{ $gr } > 0;
  }

my $d = gethrtime() - $s;
print $d / 1000_000_000;
print " secs\n";

my $s = gethrtime();
my @res;

@res = grep { /^[:@]/ } qw( 123 qwe 13 sdf dfg dfg dfk  iu hgiu ib giuh nh  hsdf sf sdf sdf sdf w erwerf we wer wer wer wer wer wer we rw er wer wer wer wer wer wer  wer  ) for 1..1000;
my $d = gethrtime() - $s;
print $d / 1000_000_000;
print " secs\n";
=cut
