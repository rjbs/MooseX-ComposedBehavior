use strict;
use warnings;

use Test::More;

{
  package Foo;
  use Moose::Role;
  use t::TagProvider;

  add_tags { qw(foo bar) };
}

{
  package Bar;
  use Moose::Role;
  use t::TagProvider;

  add_tags { qw(bar quux) };
}

{
  package OneOffTags;
  use Moose::Role;

  has tags => (
    isa => 'ArrayRef[Str]',
    traits   => [ 'Array' ],
    handles  => { _instance_tags => 'elements' },
    default  => sub {  []  },
    init_arg => 'tags',
  );
}

{
  package Thing;
  use Moose;
  use t::TagProvider;

  with qw(Foo Bar OneOffTags);

  add_tags { qw(bingo) };
}

{
  package OtherThing;
  use Moose;
  use t::TagProvider;

  with qw(Bar OneOffTags);
}

my $obj = Thing->new({ tags => [ qw(xyzzy) ] });
is_deeply(
  [ sort $obj->tags ],
  [ sort qw(foo bar bar quux bingo xyzzy) ],
  "composed tags from classes, roles, and instance",
);

is(
  $obj->tags,
  4,
  "our contrived scalar context composition",
);

is_deeply(
  [ sort OtherThing->new->tags ],
  [ sort qw(bar quux) ],
  "more composed tags from classes",
);

done_testing;
