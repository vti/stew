package App::stew::snapshot;

use strict;
use warnings;

use File::Spec   ();
use Data::Dumper ();
use Carp qw(croak);
use App::stew::util qw(slurp_file write_file);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{base} = $params{base};
    croak 'base is required' unless $self->{base};

    $self->{snapshot} = {};
    $self->load;

    return $self;
}

sub is_installed {
    my $self = shift;
    my ($stew) = @_;

    my $package = ref $stew ? $stew->package : $stew;

    if ($self->{snapshot}->{$package}) {
        return 1;
    }

    return 0;
}

sub get_package {
    my $self = shift;
    my ($package) = @_;

    return $self->{snapshot}->{$package};
}

sub load {
    my $self = shift;

    my $install_file = $self->_install_file;

    my $installed = {};
    if (-e $install_file) {
        no strict;
        $installed = eval slurp_file($install_file);
    }

    $self->{snapshot} = $installed;

    return $self->{snapshot};
}

sub mark_installed {
    my $self = shift;
    my ($stew, $files) = @_;

    $self->{snapshot}->{$stew->package} = {};
    $self->{snapshot}->{$stew->package}->{files} = [@$files];
    $self->store;

    return $self;
}

sub mark_uninstalled {
    my $self = shift;
    my ($stew) = @_;

    my $package = ref $stew ? $stew->package : $stew;

    delete $self->{snapshot}->{$package};
    $self->store;

    return $self;
}

sub store {
    my $self = shift;

    write_file($self->_install_file, Data::Dumper::Dumper($self->{snapshot}));

    return $self;
}

sub _install_file {
    my $self = shift;

    return File::Spec->catfile($self->{base}, 'stew.snapshot');
}

1;
