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
  
  bless $des,          "${prefix}::Table::Description";
  bless $des->{ '@' }, "${prefix}::Table::Category::Self::Description";
  $des->{ '@' }{ ':SUPER_CB' } = $super_cb; 
  
  for my $cat ( @cats )
    {
    my $p = str_capitalize( $cat );
    for my $item ( values %{ $des->{ $cat } } )
      {
      bless $item, "${prefix}::Table::Category::${p}::Description";
      $item->{ ':SUPER_CB' } = $super_cb; 
      }
    }  

  return 1;
}

### EOF ######################################################################
1;
