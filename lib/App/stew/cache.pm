package App::stew::cache;

use strict;
use warnings;

use File::Spec ();
use File::Path qw(mkpath);
use File::Copy qw(copy);
use File::Basename qw(dirname basename);
use App::stew::util qw(error);
use App::stew::file;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{path} = $params{path};
    $self->{repo} = $params{repo};
    $self->{os}   = $params{os};
    $self->{arch} = $params{arch};

    return $self;
}

sub sync_stew {
    my $self = shift;
    my ($name, $type) = @_;

    my $stew = $self->_get_stew($name, $type);

    $self->_get_src($stew);
    $self->_get_dist($stew);

    my @makedepends = $stew->makedepends;
    foreach my $makedepends (@makedepends) {
        $self->sync_stew($makedepends, 'makedepends');
    }

    my @depends = $stew->depends;
    foreach my $depends (@depends) {
        $self->sync_stew($depends, 'depends');
    }

    return $stew;
}

sub cache_dist {
    my $self = shift;
    my ($dist_path) = @_;

    my $to = File::Spec->catfile($self->{path}, '.cache', 'dist',
        $self->{os}, $self->{arch}, basename($dist_path));

    #warn "Caching '$dist_path' to '$to'";

    mkpath dirname $to;
    copy($dist_path, $to) or error("Can't copy '$dist_path' to '$to': $!");

    return $self;
}

sub get_stew_filepath {
    my $self = shift;
    my ($name) = @_;

    return File::Spec->catfile($self->{path}, '.cache', 'stew',
        $name . '.stew');
}

sub get_src_filepath {
    my $self = shift;
    my ($stew) = @_;

    return File::Spec->catfile($self->{path}, '.cache', 'src', $stew->file);
}

sub get_dist_filepath {
    my $self = shift;
    my ($stew) = @_;

    return File::Spec->catfile($self->{path}, '.cache', 'dist',
        $self->{os}, $self->{arch}, $stew->package . '-dist.tar.gz');
}

sub _get_stew {
    my $self = shift;
    my ($name, $type) = @_;

    my $local_path = $self->get_stew_filepath($name);
    #warn "Checking local cache '$local_path'";
    if (!-e $local_path) {
        #warn "Getting from repository '$name'";
        $self->{repo}->mirror_stew($name, $local_path);
    }

    die qq{Cannot get stew file for '$name'} unless -e $local_path;

    return $self->_parse_stew($local_path, $type);
}

sub _get_src {
    my $self = shift;
    my ($stew) = @_;

    my $local_path = $self->get_src_filepath($stew);
    #warn "Checking local cache '$local_path'";
    if (!-e $local_path) {
        #warn sprintf "Getting from repository '%s'", $stew->file;
        $self->{repo}
          ->mirror_src($self->{os}, $self->{arch}, $stew->file, $local_path);
    }

    die sprintf qq{Cannot get source file for '%s'}, $stew->file
      unless -e $local_path;

    return;
}

sub _get_dist {
    my $self = shift;
    my ($stew) = @_;

    my $local_path = $self->get_dist_filepath($stew);
    if (!-e $local_path) {
        $self->{repo}->mirror_dist($self->{os}, $self->{arch}, $stew->package,
            $local_path);
    }

    return unless -e $local_path;
    return $local_path;
}

sub _parse_stew {
    my $self = shift;
    my ($file, $type) = @_;

    return App::stew::file->parse($file, $type);
}

1;
