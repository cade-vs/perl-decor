package decor::tables::[--TABLE--];
use strict;

use Decor::Core::Shop;
use Decor::Core::Methods;
use Decor::Core::Subs::Env;

# my $user_rec  = subs_get_current_user();
# my $user_data = $user_rec->read( 'DATA' );
# my $sess_rec  = subs_get_current_session();
# my $prof_rec  = subs_get_current_profile();

#-----------------------------------------------------------------------------

sub on_recalc
{
  my $r = shift;
}

sub on_recalc_insert
{
  my $r = shift;
}

sub on_recalc_update
{
  my $r = shift;
}

#-----------------------------------------------------------------------------

sub on_insert
{
  my $r = shift;

  # on_recalc( $r );
  # on_recalc_insert( $r );
}

sub on_update
{
  my $r = shift;

  # on_recalc( $r );
  # on_recalc_update( $r );
}

#-----------------------------------------------------------------------------

sub on_post_insert
{
  my $r = shift;
}

sub on_post_update
{
  my $r = shift;
}

#-----------------------------------------------------------------------------

1;
