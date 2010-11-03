package t::TagProvider;

use MooseX::ComposedBehavior -compose => {
  sugar_name   => 'add_tags',
  also_compose => '_instance_tags',
  compositor   => sub {
    my ($self, $results) = @_;
    return map { @$_ } @$results;
  },
  method_name  => 'tags',
};

1;
