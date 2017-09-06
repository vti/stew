package App::stew::file::yml;

use strict;
use warnings;

use YAML::Tiny ();
use Cwd qw(getcwd);
use App::stew::util qw(slurp_file error listify cmd _chdir);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    my $file    = $params{file};
    my $content = $params{content};

    $self->_parse_yaml($content);

    return $self;
}

sub name {
    my $self = shift;

    return $self->{yaml}->{name};
}

sub version {
    my $self = shift;

    return $self->{yaml}->{version};
}

sub package {
    my $self = shift;

    return $self->{yaml}->{package};
}

sub url {
    my $self = shift;

    return $self->{yaml}->{url};
}

sub file {
    my $self = shift;

    return $self->{yaml}->{file};
}

sub files {
    my $self = shift;

    my @sources = listify $self->{yaml}->{files};
    push @sources, listify $self->{yaml}->{sources};

    return grep { defined } @sources;
}

sub os {
    my $self = shift;

    return grep { defined } listify $self->{yaml}->{os};
}

sub flags {
    my $self = shift;

    return grep { defined } listify $self->{yaml}->{flags};
}

sub is {
    my $self = shift;
    my ($flag) = \@_;

    return !!grep { $_ eq $flag } $self->flags;
}

sub depends {
    my $self = shift;

    return listify $self->{yaml}->{depends};
}

sub run {
    my $self = shift;
    my ($phase) = @_;

    my $steps = $self->{yaml}->{$phase};

    my $cwd = getcwd();

    foreach my $step (@$steps) {
        if (my $cmd = $step->{cmd}) {
            $cmd = $self->_parse_dynamic_var($cmd);

            cmd($cmd);
        }
        elsif (my $chdir = $step->{chdir}) {
            $chdir = $self->_parse_dynamic_var($chdir);

            _chdir($chdir);
        }
        elsif (my $env = $step->{env}) {
            foreach my $key (keys %$env) {
                $ENV{$key} = $env->{$key};
            }
        }
    }

    _chdir($cwd);
}

sub _parse_yaml {
    my $self = shift;
    my ($content) = @_;

    my $yaml = YAML::Tiny->read_string($content);
    $yaml = $yaml->[0];

    $yaml->{PREFIX}  = $ENV{PREFIX};
    $yaml->{OS}      = $ENV{STEW_OS};
    $yaml->{ARCH}    = $ENV{STEW_ARCH};

    $yaml = _walk(
        $yaml,
        sub {
            return unless defined $_[0];

            $_[0] =~ s/\{\{([_a-zA-Z0-9]+)\}\}/defined $yaml->{$1} ? $yaml->{$1} : ''/ge;

            return $_[0];
        }
    );

    $self->{yaml} = $yaml;
}

sub _parse_dynamic_var {
    my $self = shift;
    my ($template) = @_;

    $template =~ s/\$\{([_a-zA-Z0-9]+)\}/$ENV{$1}/ge;

    return $template;
}

sub _walk {
    my ($tree, $cb) = @_;

    unless (ref $tree) {
        $tree = $cb->($tree);
        return $tree;
    }

    if (ref $tree eq 'HASH') {
        foreach my $key (keys %$tree) {
            $tree->{$key} = _walk($tree->{$key}, $cb);
        }
        return $tree;
    }
    elsif (ref $tree eq 'ARRAY') {
        foreach my $value (@$tree) {
            $value = _walk($value, $cb);
        }
        return $tree;
    }
    else {
        die 'Unexpected ref=' . ref($tree);
    }

}

1;
