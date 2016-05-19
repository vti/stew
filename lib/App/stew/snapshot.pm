package App::stew::snapshot;

use strict;
use warnings;

use File::Spec ();
use List::Util qw(first);
use YAML::Tiny ();
use Carp qw(croak);
use File::Basename qw(dirname);
use App::stew::util qw(error slurp_file write_file _mkpath);

my %CACHE_REQUIRED;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{base} = $params{base};
    croak 'base is required' unless $self->{base};

    $self->{prefix} = $params{prefix} || 'local';

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
    my ($name, $version) = @_ == 1 ? split /_/, $_[0], 2 : @_;

    return 0 unless $self->is_installed($name);

    return 0 unless $self->{snapshot}->{$name}->{version} eq $version;

    return 1;
}

sub get_package {
    my $self = shift;
    my ($package) = @_;

    return $self->{snapshot}->{$package};
}

sub list_not_required {
    my $self = shift;

    my @not_required;
    foreach my $name (keys %{$self->{snapshot}}) {
        push @not_required, $name unless $self->is_required($name);
    }

    return sort @not_required;
}

sub is_dependency {
    my $self = shift;
    my ($name) = @_;

    my $info = $self->{snapshot}->{$name};
    error 'unknown package' unless $info;

    return !!$info->{dependency};
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
            my $is_required = $self->is_required($dependant_name);
            return $is_required if $is_required;
        }
    }

    return ($CACHE_REQUIRED{$name} = 0);
}

sub load {
    my $self = shift;

    my $install_file = $self->_install_file;
    $install_file = $self->_install_file_old unless -e $install_file;

    my $installed = {};
    if (-e $install_file) {
        my $content = slurp_file($install_file);

        if ($content =~ m/^\$VAR1 = /) {
            no strict;
            $installed = eval $content;
        }
        else {
            $installed = YAML::Tiny::Load($content);
        }
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

    _mkpath(dirname($self->_install_file));
    write_file($self->_install_file, YAML::Tiny::Dump($self->{snapshot}));

    unlink $self->_install_file_old;

    return $self;
}

sub _install_file {
    my $self = shift;

    return File::Spec->catfile($self->{base}, $self->{prefix}, 'stew.snapshot');
}

sub _install_file_old {
    my $self = shift;

    return File::Spec->catfile($self->{base}, 'stew.snapshot');
}

1;
