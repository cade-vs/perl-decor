##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Describe;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                bless_description_tree

                );

my %REQUIRE_SEEN;

##############################################################################

# will attach proper classes to all items in the description :)
# needs:
# 1. description tree hashref
# 2. class prefix
# 3. categories list

sub bless_description_tree
{
# print STDERR Dumper( \@_, Exception::Sink::get_stack_trace() );

  my $des    = shift;
  my $prefix = shift;
  my @cats   = @_;

  my $super_cb    = sub { return $des };

  require_and_bless_ref( $des,          "${prefix}::Description::Table" );
  require_and_bless_ref( $des->{ '@' }, "${prefix}::Description::Table::Category::Self" );

  $des->{ '@' }{ ':SUPER_CB' } = $super_cb; 
  
  for my $cat ( @cats )
    {
    my $p = str_capitalize( $cat );
    for my $item ( values %{ $des->{ $cat } } )
      {
      require_and_bless_ref( $item, "${prefix}::Description::Table::Category::${p}" );
      $item->{ ':SUPER_CB' } = $super_cb; 
      }
    }  

  return 1;
}

# TODO: move to data::tools with 3rd arg, seen cache hashref
sub require_and_bless_ref
{
  my $ref = shift;
  my $pkg = shift;

  unless( $REQUIRE_SEEN{ $pkg }++ )
    {
    eval
      {
      require scalar perl_package_to_file( $pkg );
      };
    if( $@ )
      {
      boom "bless_description_tree: require failed for [$pkg] $@\n";
      }
    $REQUIRE_SEEN{ $pkg }++;
    }

  bless $ref, $pkg;
}

### EOF ######################################################################
1;
