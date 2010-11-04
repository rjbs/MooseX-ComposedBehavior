package MooseX::ComposedBehavior::Guts;
use MooseX::Role::Parameterized;

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

role {
  my ($p) = @_;

  my $wantarray = $p->forces_context ? ($p->context eq 'list' ? 1 : 0) : undef;

  my $stub_name = $p->stub_method_name;
  method $stub_name => sub { };

  my $method_name  = $p->method_name;
  my $compositor   = $p->compositor;
  my $also_compose = $p->also_compose;

  method $method_name => sub {
    my $self    = shift;

    my $results = [];

    my $wantarray = defined $wantarray ? $wantarray : wantarray;

    foreach my $method (
      reverse
      Class::MOP::class_of($self)->find_all_methods_by_name($stub_name)
    ) {
      my @array;
      $wantarray ? (@array = $method->{code}->execute($self, \@_, $results))
                 : (scalar $method->{code}->execute($self, \@_, $results));
    }

    if (defined $also_compose) {
      for my $also_method (@$also_compose) {
        push @$results, ($wantarray
          ? [ $self->$also_method(@_) ] : scalar $self->$also_method(@_));
      }
    }

    return $compositor->($self, \@$results);
  }
};

1;
