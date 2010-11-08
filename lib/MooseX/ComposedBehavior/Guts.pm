package MooseX::ComposedBehavior::Guts;
use MooseX::Role::Parameterized;
# ABSTRACT: the gooey, meaty bits that help MooseX::ComposedBehavior work

=head1 OVERVIEW

MooseX::ComposedBehavior::Guts contains a bunch of code that is used by
L<MooseX::ComposedBehavior> to get its job done.  It is basically a hack, and
relying on any part of its interface would be a I<terrible> idea.

Reading the source, on the other hand, might be useful in understanding what
the heck is going on, especially if you encounter weird problem.

=cut

use Moose::Util::TypeConstraints;

parameter stub_method_name => (
  isa => 'Str',
  required => 1,
);

parameter method_name => (
  isa => 'Str',
  required => 1,
);

subtype 'MooseX::ComposedBehavior::Stub::_MethodList',
  as 'ArrayRef[Str|CodeRef]';

coerce 'MooseX::ComposedBehavior::Stub::_MethodList',
  from 'CodeRef', via { [$_] },
  from 'Str',     via { [$_] };

parameter also_compose => (
  isa    => 'MooseX::ComposedBehavior::Stub::_MethodList',
  coerce => 1,
);

parameter compositor => (
  isa => 'CodeRef',
  required => 1,
);

parameter context => (
  isa       => enum([ qw(list scalar) ]),
  predicate => 'forces_context',
);

parameter method_order => (
  isa     => enum([ qw(standard reverse) ]),
  default => 'standard',
);

role {
  my ($p) = @_;

  my $wantarray = $p->forces_context ? ($p->context eq 'list' ? 1 : 0) : undef;

  my $stub_name = $p->stub_method_name;
  method $stub_name => sub { };

  my $method_name  = $p->method_name;
  my $compositor   = $p->compositor;
  my $also_compose = $p->also_compose;
  my $reverse      = $p->method_order eq 'reverse';

  method $method_name => sub {
    my $self    = shift;

    my $results   = [];
    my $providers = [];

    my $wantarray = defined $wantarray ? $wantarray : wantarray;

    my @methods = Class::MOP::class_of($self)
                ->find_all_methods_by_name($stub_name);

    @methods = reverse @methods if $reverse;

    foreach my $method (@methods) {
      if ($wantarray) {
        () = $method->{code}->execute($self, \@_, $results, $providers);
      } else {
        scalar $method->{code}->execute($self, \@_, $results, $providers);
      }
    }

    if (defined $also_compose) {
      for my $also_method (@$also_compose) {
        push @$results, ($wantarray
          ? [ $self->$also_method(@_) ] : scalar $self->$also_method(@_));

        push @$providers, $also_method;
      }
    }

    return $compositor->($self, $results, $providers);
  }
};

1;
