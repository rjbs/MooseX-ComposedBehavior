package t::TagReverse;
use strict;

use MooseX::ComposedBehavior -compose => {
  sugar_name   => 'add_tags',
  also_compose => '_instance_tags',
  context      => 'list',
  compositor   => sub {
    my ($self, $results) = @_;
    return map { @$_ } @$results if wantarray;
  },
  method_name  => 'tags',
  method_order => 'reverse',
};

1;
