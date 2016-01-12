package App::stew::index;

use strict;
use warnings;

use Carp qw(croak);
use List::Util qw(first);
use App::stew::util qw(error);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{repo} = $params{repo} or croak 'repo required';

    return $self;
}

sub resolve {
    my $self = shift;
    my ($need) = @_;

    my $name = $need;
    my $op;
    my $version;
    if ($need =~ m/^(.*?)(==|>=?|<=?)(.*)$/) {
        $name    = $1;
        $op      = $2;
        $version = $3;
    }

    $self->{index} ||= $self->_read_index;

    my @packages;
    foreach my $package (@{$self->{index}}) {
        push @packages, $package if $package->{name} eq $name;
    }

    if (!$op) {
        my $package = $packages[-1];
        return unless $package;

        return $package->{full};
    }
    elsif ($op eq '==') {
        my $package = first { $_->{version} eq $version } @packages;
        return unless $package;

        return $package->{full};
    }
    elsif ($op eq '>=') {
        my $package = first { $_->{version} ge $version } @packages;
        return unless $package;

        return $package->{full};
    }
    elsif ($op eq '>') {
        my @packages = grep { $_->{version} gt $version } @packages;
        return unless @packages;

        return $packages[-1]->{full};
    }

    return;
}

sub list_platforms {
    my $self = shift;

    my @platforms;

    my $index_file = $self->{repo}->mirror_index;

    my @index;
    open my $fh, '<', $index_file
      or error "Can't read index file '$index_file': $!";
    foreach my $line (<$fh>) {
        chomp $line;
        next unless $line =~ m/^dist\/(.*?)\/(.*?)$/;

        push @platforms, "$1-$2";
    }
    close $fh;

    return \@platforms;
}

sub platform_available {
    my $self = shift;
    my ($platform) = @_;

    my $platforms = $self->list_platforms;

    if (grep { $platform eq $_ } @$platforms) {
        return 1;
    }

    return 0;
}

sub _read_index {
    my $self = shift;

    my $index_file = $self->{repo}->mirror_index;

    my @index;
    open my $fh, '<', $index_file
      or error "Can't read index file '$index_file': $!";
    foreach my $line (<$fh>) {
        chomp $line;
        next unless $line =~ m/^stew\/(.*?)_(.*?)\.stew$/;

        push @index,
          {
            name    => $1,
            version => $2,
            full    => "$1_$2"
          };
    }
    close $fh;

    return \@index;
}

1;
