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
use Decor::Core::Role;

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

my $role = new Decor::Core::Role( STAGE => $stage );
$role->add_groups( qw( admin1 root user 1342 ) );
print STDERR Dumper( $role );

my %TMP_DES;
my %TMP_ROLE;
$TMP_DES{ 'test1' }{ '@' }{ 'update' } = 'admin';
%TMP_ROLE = map { $_ => 1 } qw( admin1 root user 1342 );

my $s = gethrtime();

for( 1..1000_000 )
  {
  print "YES ACCESS ROLE\n" if $role->access_table( 'test1', 'update' );
  }

my $d = gethrtime() - $s;

print $d / 1000_000_000;
print " secs\n";

my $s = gethrtime();

my $gr = $TMP_DES{ 'test1' }{ '@' }{ 'update' };
for( 1..1000_000 )
  {
  print "YES ACCESS HASH\n" if exists $TMP_ROLE{ $gr } and $TMP_ROLE{ $gr } > 0;
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
