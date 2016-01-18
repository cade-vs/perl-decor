#!/usr/bin/perl
##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use FindBin;
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../../lib";

use Time::HR;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Stage;
use Decor::Core::Profile;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $root = de_root();

de_set_debug( 1 );

my $stage = Decor::Core::Stage->new( 'app1' );
$stage->init( $root );

print STDERR Dumper( $stage );

my $des = $stage->describe_table( 'test1' );
my $des = $stage->describe_table( 'test1' );

print STDERR '='x80;

print STDERR Dumper( $des );
print STDERR Dumper( [ $des->fields() ] );
#print STDERR Dumper( $des->get_table_des() );

my $profile = new Decor::Core::Profile( STAGE => $stage );
$profile->add_groups( qw( admin1 root monitor users 1342 ) );
print STDERR Dumper( $profile );

my %TMP_DES;
my %TMP_PROFILE;
$TMP_DES{ 'test1' }{ '@' }{ 'update' } = 'admin';
%TMP_PROFILE = map { $_ => 1 } qw( admin1 root user 1342 );

print "-------------------------------------------------access test-----\n";

$profile->set_groups( qw( admin1 root1 monitor users 1342 ) );
print "YES ACCESS PROFILE\n" if $profile->access_table( 'test1', 'update' );


my $s = gethrtime();

my $c;
for( 1..100_000 )
  {
  $c++ if $profile->access_table( 'update', 'test1' );
  }

my $d = gethrtime() - $s;

print $d / 1000_000_000;
print " secs c[$c]\n";

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
