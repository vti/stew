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

sub local_settings {
    my $self = shift;

    $self->{snapshot}->{_} ||= {};

    return $self->{snapshot}->{_};
}

sub is_installed {
    my $self = shift;
    my ($package) = @_;

    if ($self->{snapshot}->{$package}) {
        return 1;
    }

    return 0;
}

sub is_up_to_date {
    my $self = shift;
    my ($package, $version) = @_;

    return 0 unless $self->is_installed($package);

    return 0 unless $self->{snapshot}->{$package}->{version} eq $version;

    return 1;
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
    my ($name, $version, $files) = @_;

    $self->{snapshot}->{$name} = {version => $version, files => $files};
    $self->store;

    return $self;
}

sub mark_uninstalled {
    my $self = shift;
    my ($name) = @_;

    delete $self->{snapshot}->{$name};
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
