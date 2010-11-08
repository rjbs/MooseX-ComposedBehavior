use strict;
use warnings;

use Test::More;

{
  package Class;
  use Moose;
  use t::TagProvider;
  sub _instance_tags {}
  add_tags { qw(parent) };
}

{
  package Subclass;
  use Moose;
  use t::TagProvider;
  extends 'Class';
  add_tags { qw(child) };
}

{
  package ClassR;
  use Moose;
  use t::TagReverse;
  sub _instance_tags {}
  add_tags { qw(parent) };
}

{
  package SubclassR;
  use Moose;
  use t::TagReverse;
  extends 'ClassR';
  add_tags { qw(child) };
}

my $obj = Subclass->new;
is_deeply(
  [ $obj->tags ],
  [ qw(child parent) ],
  "tags returned in default order",
);

my $rev = SubclassR->new;
is_deeply(
  [ $rev->tags ],
  [ qw(parent child) ],
  "tags returned in reverse order",
);


done_testing;
