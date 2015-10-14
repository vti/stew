package App::stew::snapshot;

use strict;
use warnings;

use File::Spec   ();
use Data::Dumper ();
use App::stew::util qw(slurp_file write_file);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{base} = $params{base};

    $self->{snapshot} = {};
    $self->load;

    return $self;
}

sub is_installed {
    my $self = shift;
    my ($stew) = @_;

    if ($self->{snapshot}->{$stew->package}) {
        return 1;
    }

    return 0;
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

    return $self;
}

sub mark_installed {
    my $self = shift;
    my ($stew) = @_;

    $self->{snapshot}->{$stew->package}++;
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
