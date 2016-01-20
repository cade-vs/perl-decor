#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' );

use FindBin;
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../lib";

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

$stage->__dsn_parse_config();
my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

$stage->dsn_reset();

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;
