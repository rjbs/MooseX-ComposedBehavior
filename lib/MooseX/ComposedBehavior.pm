use strict;
use warnings;
package MooseX::ComposedBehavior;
# ABSTRACT: implement custom strategies for composing units of code

=begin :prelude

=head1 OVERVIEW

First, B<a warning>:  MooseX::ComposedBehavior is a weird and powerful tool
meant to be used only I<well> after traditional means of composition have
failed.  Almost everything most programs will need can be represented with
Moose's normal mechanisms for roles, classes, and method modifiers.
MooseX::ComposedBehavior addresses edge cases.

Second, B<another warning>:  the API for MooseX::ComposedBehavior is not quite
stable, and may yet change.  More likely, though, the underlying implementation
may change.  The current implementation is something of a hack, and should be
replaced by a more robust one.  When that happens, if your code is not sticking
strictly to the MooseX::ComposedBehavior API, you will probably have all kinds
of weird problems.

=end :prelude

=head1 SYNOPSIS

First, you describe your composed behavior, say in the package "TagProvider":

  package TagProvider;
  use strict;

  use MooseX::ComposedBehavior -compose => {
    method_name  => 'tags',
    sugar_name   => 'add_tags',
    context      => 'list',
    compositor   => sub {
      my ($self, $results) = @_;
      return map { @$_ } @$results if wantarray;
    },
  };

Now, any class or role can C<use TagProvider> to declare that it's going to
contribute to a collection of tags.  Any class that has used C<TagProvider>
will have a C<tags> method, named by the C<method_name> argument.  When it's
called, code registered the class's constituent parts will be called.  For
example, consider this example:

  {
    package Foo;
    use Moose::Role;
    use TagProvider;
    add_tags { qw(foo baz) };
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
  }

Now, when you say:

  my $thing = Thing->new;
  my @tags  = $thing->tags;

...each of the C<add_tags> code blocks above is called.  The result of each
block is gathered and an arrayref of all the results is passed to the
C<compositor> routine.  The one we defined above is very simple, and just
concatenates all the results together.

C<@tags> will contain, in no particular order: foo, bar, baz, quux, and bingo

Result composition can be much more complex, and the context in which the
registered blocks are called can be controlled.  The options for composed
behavior are described below.

=head1 HOW TO USE IT

=for :list
1. make a helper module, like the "TagProvider" one above
2. C<use> the helper in every relevant role or class
3. write blocks using the "sugar" function
4. call the method on instances as needed
5. you're done!

There isn't much to using it beyond knowing how to write the actual behavior
compositor (or "helper module") that you want.  Helper modules will probably
always be very short: package declaration, C<use strict>,
MooseX::ComposedBehavior invocation, and nothing more.  Everything important
goes in the arguments to MooseX::ComposedBehavior's import routine:

  package MyHelper;
  use strict;

  use MooseX::ComposedBehavior -compose => {
    ... important stuff goes here ...
  };

  1;

=head2 Options to MooseX::ComposedBehavior

=begin :list

= C<method_name>

This is the name of the method that you'll call to get composed results.  When
this method is called, all the registered behavior is run, the results
gathered, and those results passed to the compositor (described below).

= C<sugar_name>

This is the of the sugar to export into packages using the helper module.  It
should be called like this (assuming the C<sugar_name> is C<add_behavior>):

  add_behavior { ...the behavior... ; return $value };

When this block is invoked, it will be passed the invocant (the class or
instance) followed by all the arguments passed to the main method -- that is,
the method named by C<method_name>.

= C<context>

This parameter forces a specific calling context on the registered blocks of
behavior.  It can be either "scalar" or "list" or may be omitted.  The blocks
registered by the sugar function will always be called in the given context.
If no context is given, they will be called in the same context that the main
method was called.

The C<context> option does I<not> affect the context in which the compositor is
called.  It is always called in the same context as the main method.

Void context is propagated as scalar context.  B<This may change in the
future> to support void context per se.

= C<compositor>

The compositor is a coderef that gets all the results of registered behavior
(and C<also_compose>, below) and combines them into a final result, which will
be returned from the main method.

It is passed the invocant, followed by an arrayref of block results.  The
block results are in an undefined order.  If the blocks were called in scalar
context, each block's result is the returned scalar.  If the blocks were called
in list context, each block's result is an arrayref containing the returned
list.

The compositor is I<always> called in the same context as the main method, even
if the behavior blocks were forced into a different context.

= C<also_compose>

This parameter is a coderef or method name, or an arrayref of coderefs and/or
method names.  These will be called along with the rest of the registered
behavior, in the same context, and their results will be composed like any
other results.  It would be possible to simply write this:

  add_behavior {
    my $self = shift;
    $self->some_method;
  };

...but if this was somehow composed more than once (by repeating a role
application, for example) you would get the results of C<some_method> more than
once.  By putting the method into the C<also_compose> option, you are
guaranteed that it will run only once.

=end :list

=cut

use MooseX::ComposedBehavior::Guts;

use Sub::Exporter -setup => {
  groups => [ compose => \'_build_composed_behavior' ],
};

my $i = 0;

sub _build_composed_behavior {
  my ($self, $name, $arg, $col) = @_;

  my %sub;

  my $sugar_name = $arg->{sugar_name};
  my $stub_name  = 'MooseX_ComposedBehavior_' . $i++ . "_$sugar_name";

  my $role = MooseX::ComposedBehavior::Guts->meta->generate_role(
    parameters => {
      stub_method_name => $stub_name,
      compositor       => $arg->{compositor},
      method_name      => $arg->{method_name},
      also_compose     => $arg->{also_compose},

      (defined $arg->{method_order} ? (method_order => $arg->{method_order})
        : ()),

      (defined $arg->{context} ? (context => $arg->{context}) : ()),
    },
  );

  my $import = Sub::Exporter::build_exporter({
    groups  => [ default => [ $sugar_name ] ],
    exports => {
      $sugar_name => sub {
        my ($self, $name, $arg, $col) = @_;
        my $target = $col->{INIT}{target};
        return sub (&) {
          my ($code) = shift;

          Moose::Util::add_method_modifier(
            $target->meta,
            'around',
            [
              $stub_name,
              sub {
                my ($orig, $self, $arg, $col) = @_;

                my @array = (wantarray
                  ? $self->$code(@$arg)
                  : scalar $self->$code(@$arg)
                );

                push @$col, wantarray ? \@array : $array[0];
                $self->$orig($arg, $col);
              },
            ],
          );
        }
      },
    },
    collectors => {
      INIT => sub {
        my $target = $_[1]{into};
        $_[0] = { target => $target };
        Moose::Util::apply_all_roles($target, $role);
        return 1;
      },
    },
  });
  
  $sub{import} = $import;

  return \%sub;
}

1;
