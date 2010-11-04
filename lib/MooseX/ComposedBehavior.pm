use strict;
use warnings;
package MooseX::ComposedBehavior;

use MooseX::ComposedBehavior::Stub;

use Sub::Exporter -setup => {
  groups => [ compose => \'_build_composed_behavior' ],
};

my $i = 0;

sub _build_composed_behavior {
  my ($self, $name, $arg, $col) = @_;

  my %sub;

  my $sugar_name = $arg->{sugar_name};
  my $stub_name  = 'MooseX_ComposedBehavior_' . $i++ . "_$sugar_name";

  my $role = MooseX::ComposedBehavior::Stub->meta->generate_role(
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
