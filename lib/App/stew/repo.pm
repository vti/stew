package App::stew::repo;

use strict;
use warnings;

use HTTP::Tiny;
use File::Basename qw(dirname basename);
use File::Path ();
use Carp qw(croak);
use App::stew::util qw(error debug _copy _mkpath sort_by_version);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{path} = $params{path} or croak 'path required';
    $self->{path} .= '/' unless $self->{path} =~ m{/$};

    $self->{mirror_path} = $params{mirror_path} or croak 'mirror_path required';
    $self->{mirror_path} .= '/' unless $self->{mirror_path} =~ m{/$};

    $self->{os}   = $params{os}   or croak 'os required';
    $self->{arch} = $params{arch} or croak 'arch required';

    $self->{ua}    = $params{ua};
    $self->{cache} = $params{cache};

    return $self;
}

sub mirror_stew {
    my $self = shift;
    my ($name) = @_;

    my $full_name =
      $self->{path} . File::Spec->catfile('stew', $name . '.stew');

    return $self->mirror_file($full_name,
        File::Spec->catfile($self->{mirror_path}, 'stew'));
}

sub mirror_src {
    my $self = shift;
    my ($filename) = @_;

    my $full_name = $self->{path} . File::Spec->catfile('src', $filename);

    return $self->mirror_file($full_name,
        File::Spec->catfile($self->{mirror_path}, 'src'));
}

sub mirror_dist_dest {
    my $self = shift;
    my ($name, $version) = @_;

    my $os   = $self->{os};
    my $arch = $self->{arch};

    return File::Spec->catfile($self->{mirror_path}, 'dist', $os, $arch,
        "${name}_${version}_$os-$arch.tar.gz");
}

sub mirror_dist {
    my $self = shift;
    my ($name, $version) = @_;

    croak 'name required'     unless $name;
    croak 'version required ' unless $version;

    my $os   = $self->{os};
    my $arch = $self->{arch};

    my $full_name = $self->{path}
      . File::Spec->catfile('dist', $os, $arch,
        "${name}_${version}_$os-$arch.tar.gz");

    return $self->mirror_file($full_name,
        File::Spec->catfile($self->{mirror_path}, 'dist', $os, $arch));
}

sub mirror_index {
    my $self = shift;

    my $to = File::Spec->catfile($self->{mirror_path}, 'index');

    if ($self->{cache}) {
        debug("NOT Mirroring index");
        return $to;
    }

    my @index;

    if ($self->{path} =~ m/^http/) {
        my $ua = $self->{ua} || HTTP::Tiny->new;

        for my $type (qw(stew src)) {
            my $response = $ua->get("$self->{path}$type");

            if ($response->{success}) {
                my $content = $response->{content};

                while (
                    $content =~ m#<a href="(.*?\.(?:stew|tar\.gz))">.*?</a>#g)
                {
                    push @index, "$type/$1";
                }
            }
        }

        my $response = $ua->get("$self->{path}dist");
        if ($response->{success}) {
            my $content = $response->{content};

            my @os;
            while ($content =~ m#<a href="([^\.].*?)/?">.*?</a>#g) {
                push @os, $1;
            }

            foreach my $os (@os) {
                my $response = $ua->get("$self->{path}dist/$os");
                next unless $response->{success};

                my $content = $response->{content};
                while ($content =~ m#<a href="([^\.].*?)/?">.*?</a>#g) {
                    push @index, "dist/$os/$1";
                }
            }
        }
    }
    else {
        for my $type (qw(stew src)) {
            opendir my $dh, "$self->{path}/$type"
              or error "Can't open directory '$self->{path}/$type': $!";
            push @index, map { "$type/$_" }
              grep { !/^\./ && -f "$self->{path}/$type/$_" } readdir($dh);
            closedir $dh;
        }

        if (opendir my $dh, "$self->{path}/dist") {
            my @os = grep { !/^\./ && -d "$self->{path}/dist/$_" } readdir($dh);
            closedir $dh;

            foreach my $os (@os) {
                opendir my $dh, "$self->{path}/dist/$os" or next;
                my @arch =
                  grep { !/^\./ && -d "$self->{path}/dist/$os/$_" }
                  readdir($dh);
                closedir $dh;

                foreach my $arch (@arch) {
                    push @index, "dist/$os/$arch";
                }
            }
        }
    }

    my @index_sorted = sort_by_version @index;

    _mkpath dirname $to;

    open my $fh, '>', $to or die "Can't create file '$to': $!";
    print $fh "$_\n" for @index_sorted;
    close $fh;

    return $to;
}

sub mirror_file {
    my $self = shift;
    my ($in, $to_dir) = @_;

    my $to = File::Spec->catfile($to_dir, basename $in);

    if ($self->{cache}) {
        debug("NOT Mirroring '$in' to '$to_dir'");
        return $to;
    }

    _mkpath($to_dir);

    debug("Mirroring '$in' to '$to_dir'");

    if (-e $to) {
        debug("File '$to' exists. Skipping");
        return $to;
    }

    if ($in =~ m/^http/) {
        my $ua = $self->{ua} || HTTP::Tiny->new;
        $ua->mirror($in, $to);
    }
    else {
        error "File '$in' does not exist" unless -f $in;

        _copy($in, $to);
    }

    return $to;
}

1;
