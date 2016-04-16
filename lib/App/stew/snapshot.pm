package App::stew::snapshot;

use strict;
use warnings;

use File::Spec   ();
use List::Util qw(first);
use Data::Dumper ();
use Carp qw(croak);
use App::stew::util qw(error slurp_file write_file);

my %CACHE_REQUIRED;

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

sub list_not_required {
    my $self = shift;
    my ($root) = @_;

    return $self->list_not_required_of($root) if $root;

    my @not_required;
    foreach my $name (keys %{$self->{snapshot}}) {
        push @not_required, $name unless $self->is_required($name);
    }

    return @not_required;
}

sub is_required {
    my $self = shift;
    my ($name) = @_;

    my $info = $self->{snapshot}->{$name};
    error 'unknown package' unless $info;

    return $CACHE_REQUIRED{$name} if exists $CACHE_REQUIRED{$name};

    return ($CACHE_REQUIRED{$name} = 1) unless $info->{dependency};

    foreach my $dependant_name (keys %{$self->{snapshot}}) {
        next if $name eq $dependant_name;

        my $dependant_info = $self->{snapshot}->{$dependant_name};
        next
          unless $dependant_info->{depends}
          && (my @depends = @{$dependant_info->{depends}});

        if (my $depends = first { $name eq $_->{name} } @depends) {
            return $self->is_required($dependant_name);
        }
    }

    return ($CACHE_REQUIRED{$name} = 0);
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
    my (%options) = @_;

    my $name = delete $options{name};

    $self->{snapshot}->{$name} = {%options};
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
