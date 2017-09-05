package App::stew::tree;

use strict;
use warnings;

use Carp qw(croak);
use App::stew::fileparser;
use App::stew::util qw(error);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{repo}  = $params{repo}  or croak 'repo required';
    $self->{index} = $params{index} or croak 'index required';

    return $self;
}

sub build {
    my $self = shift;
    my ($stew_expr, %params) = @_;

    my $stew_name = $self->{index}->resolve($stew_expr);
    error "Can't find package satisfying '$stew_expr'" unless $stew_name;

    my $stew_file = $self->_download_stew($stew_name);

    my $stew = $self->_parse_stew($stew_file);

    my $tree = {
        stew         => $stew,
        dependencies => []
    };

    return $tree if $params{seen}->{$stew_name};
    $params{seen}->{$stew_name}++;

    my @depends = $stew->depends;
    foreach my $depends (@depends) {
        push @{$tree->{dependencies}}, $self->build($depends, %params);
    }

    return $tree;
}

sub flatten {
    my $self = shift;
    my ($tree) = @_;

    my @list;

    foreach my $dep (@{$tree->{dependencies}}) {
        push @list, $self->flatten($dep);
    }

    push @list, $tree->{stew};

    return @list;
}

sub flatten_dependencies {
    my $self = shift;
    my ($tree) = @_;

    my @list;

    foreach my $dep (@{$tree->{dependencies}}) {
        push @list, $self->flatten($dep);
    }

    return @list;
}

sub _download_stew {
    my $self = shift;
    my ($stew_name) = @_;

    return $self->{repo}->mirror_stew($stew_name);
}

sub _parse_stew {
    my $self = shift;
    my ($file) = @_;

    return App::stew::fileparser->parse($file);
}

1;
