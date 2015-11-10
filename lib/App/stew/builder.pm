package App::stew::builder;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Carp qw(croak);
use File::Path qw(rmtree);
use File::Basename qw(basename dirname);
use App::stew::util
  qw(cmd info debug error _chdir _mkpath _copy _unlink _tree _tree_diff);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root_dir}  = $params{root_dir};
    $self->{build_dir} = $params{build_dir};
    $self->{repo}      = $params{repo};
    $self->{snapshot}  = $params{snapshot};

    $self->{from_source} = $params{from_source};
    $self->{reinstall}   = $params{reinstall};

    return $self;
}

sub build {
    my $self = shift;
    my ($stew_tree) = @_;

    my $stew = $stew_tree->{stew};

    if (!$self->{reinstall} && $self->{snapshot}->is_up_to_date($stew->name, $stew->version)) {
        info sprintf "'%s' is up to date", $stew->package;
        return;
    }

    croak '$ENV{PREFIX} not defined' unless $ENV{PREFIX};

    _mkpath($ENV{PREFIX});

    info sprintf "Building & installing '%s'...", $stew->package;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);

    my $cwd = getcwd();
    my $tree = [];
    eval {
        _mkpath($work_dir);
        _chdir($work_dir);

        info sprintf "Resolving dependencies...", $stew->package;
        $self->_resolve_dependencies($stew, $stew_tree);

        my $dist_path = $self->{repo}->mirror_dist_dest($stew->name, $stew->version);

        eval { $self->{repo}->mirror_dist($stew->name, $stew->version) };

        if ($self->{from_source} || !-f $dist_path) {
            my $dist_archive = basename $dist_path;
            my ($dist_name) = $dist_archive =~ m/^(.*)\.tar\.gz$/;

            $self->_build_from_source($stew, $dist_name);

            info sprintf "Caching '%s' as '$dist_archive'...", $stew->package;
            cmd("tar czhf $dist_archive $dist_name");

            _copy $dist_archive, $dist_path;
        }

        $tree = $self->_install_from_binary($stew, $dist_path);

        _chdir($cwd);
    } or do {
        my $e = $@;

        _chdir($cwd);

        die $e;
    };

    info sprintf "Done installing '%s'", $stew->package;
    $self->{snapshot}->mark_installed($stew->name, $stew->version, $tree);

    return $self;
}

sub _install_from_binary {
    my $self = shift;
    my ($stew, $dist_path) = @_;

    info sprintf "Installing '%s' from binaries...", $stew->package;

    my $basename = basename $dist_path;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir $work_dir;

    _copy($dist_path, "$basename");
    cmd("tar xzf $basename");

    my ($dist_name) = $basename =~ m/^(.*)\.tar\.gz$/;
    _chdir($dist_name);

    my $local_prefix = $ENV{PREFIX};
    $local_prefix =~ s{^/+}{};
    cmd("cp --remove-destination -ra $local_prefix/* $ENV{PREFIX}/");

    return _tree(".", ".");
}

sub _build_from_source {
    my $self = shift;
    my ($stew, $dist_name) = @_;

    info sprintf "Preparing '%s'...", $stew->package;
    $self->_prepare($stew);

    info sprintf "Building '%s'...", $stew->package;
    $self->_build($stew);

    _mkpath($ENV{PREFIX});

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    _mkpath $dist_name;
    $ENV{DESTDIR} = abs_path($dist_name);

    info sprintf "Installing '%s'...", $stew->package;
    $self->_install($stew);

    return $self;
}

sub _prepare {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _mkpath $work_dir;
    _chdir($work_dir);

    my $src_file = $self->{repo}->mirror_src($stew->file);

    _copy($src_file, $work_dir)
      or error("Copy '$src_file' to '$work_dir' failed: $!");

    my @commands = $stew->run('prepare');
    cmd(@commands);
}

sub _build {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    my @commands = $stew->run('build');
    cmd(@commands);
}

sub _install {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    my @commands = $stew->run('install');
    cmd(@commands);
}

sub _resolve_dependencies {
    my $self = shift;
    my ($stew, $tree) = @_;

    my $build_dir = $self->{build_dir};
    my $work_dir = File::Spec->catfile($build_dir, $stew->package);

    my @makedepends = @{$tree->{make_dependencies} || []};
    if (@makedepends) {
        info "Found make dependencies: " . join(', ', map { $_->{stew}->package } @makedepends);
    }
    foreach my $tree (@makedepends) {
        my $stew = $tree->{stew};

        _chdir($self->{root_dir});

        info sprintf "Preparing make dependency '%s'", $stew->package;
        $self->_prepare($stew);

        _chdir($self->{root_dir});

        my $to = sprintf '%s/%s', $work_dir, $stew->package;
        if (!-e $to) {
            cmd(sprintf "ln -s $build_dir/%s/%s $to",
                $stew->package, $stew->package);
        }
    }

    my @depends = @{$tree->{dependencies} || []};
    if (@depends) {
        info "Found dependencies: " . join(', ', map { $_->{stew}->package } @depends);
    }
    foreach my $tree (@depends) {
        my $stew = $tree->{stew};

        _chdir($self->{root_dir});

        $self->build($tree);

        _chdir($self->{root_dir});
    }
}

1;
