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
  package Thing;
  use Moose;
  use t::TagProvider;

  with qw(Foo Bar);

  add_tags { qw(bingo) };

  has tags => (
    isa => 'ArrayRef[Str]',
    traits   => [ 'Array' ],
    handles  => { _instance_tags => 'elements' },
    init_arg => 'tags',
  );
}

my $obj = Thing->new({ tags => [ qw(xyzzy) ] });
is_deeply(
  [ sort $obj->tags ],
  [ sort qw(foo bar bar quux bingo xyzzy) ],
);

