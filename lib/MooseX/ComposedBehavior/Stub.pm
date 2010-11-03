package MooseX::ComposedBehavior::Stub;
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
  as 'ArrayRef[Str]';

coerce 'MooseX::ComposedBehavior::Stub::_MethodList',
  from 'Str',
  via { [$_] };

parameter also_compose => (
  isa    => 'MooseX::ComposedBehavior::Stub::_MethodList',
  coerce => 1,
);

parameter compositor => (
  isa => 'CodeRef',
  required => 1,
);

role {
  my ($p) = @_;

  my $stub_name = $p->stub_method_name;
  method $stub_name => sub {};

  my $method_name  = $p->method_name;
  my $compositor   = $p->compositor;
  my $also_compose = $p->also_compose;

  method $method_name => sub {
    my $self    = shift;

    my $results = [];

    my @array;
    wantarray ? (@array = $self->$stub_name(\@_, $results))
              : (scalar $self->$stub_name(\@_, $results));

    if (defined $also_compose) {
      for my $also_method (@$also_compose) {
        push @$results, (wantarray 
          ? [ $self->$also_method ] : scalar $self->$also_method);
      }
    }

    return $compositor->($self, \@$results);
  }
};

1;
