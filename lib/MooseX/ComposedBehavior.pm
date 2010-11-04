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
  }

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
