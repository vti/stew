package App::stew::repo;

use strict;
use warnings;

use HTTP::Tiny;
use File::Basename ();
use File::Path ();
use App::stew::util qw(debug _copy);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{path} = $params{path};
    $self->{path} .= '/' unless $self->{path} =~ m{/$};

    return $self;
}

sub mirror_stew {
    my $self = shift;
    my ($name, $to) = @_;

    my $full_name = $self->{path} . File::Spec->catfile('stew', $name . '.stew');

    return $self->mirror_file($full_name, $to);
}

sub mirror_src {
    my $self = shift;
    my ($os, $arch, $filename, $to) = @_;

    my $full_name = $self->{path} . File::Spec->catfile('src', $filename);

    return $self->mirror_file($full_name, $to);
}

sub mirror_dist {
    my $self = shift;
    my ($os, $arch, $name, $to) = @_;

    my $full_name = $self->{path} . File::Spec->catfile('dist', $os, $arch, $name . '-dist.tar.gz');

    return $self->mirror_file($full_name, $to);
}

sub mirror_file {
    my $self = shift;
    my ($in, $out) = @_;

    debug("Mirroring '$in' to '$out'");

    File::Path::mkpath(File::Basename::dirname($out));

    if ($in =~ m/^http/) {
        HTTP::Tiny->new->mirror($in, $out);
    }
    else {
        return 0 unless -f $in;

        _copy($in, $out);
    }

    return 1;
}

1;
