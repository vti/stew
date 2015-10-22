package App::stew::builder;

use strict;
use warnings;

use Cwd qw(getcwd);
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
    $self->{cache}     = $params{cache};
    $self->{snapshot}  = $params{snapshot};

    return $self;
}

sub build {
    my $self = shift;
    my ($stew) = @_;

    if ($self->{snapshot}->is_installed($stew)) {
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
        $self->_resolve_dependencies($stew);

        my $dist_path = $self->{cache}->get_dist_filepath($stew);
        if (-f $dist_path) {
            $tree = $self->_install_from_binary($stew, $dist_path);
        }
        else {
            $tree = $self->_install_from_source($stew);
        }

        _chdir($cwd);
    } or do {
        my $e = $@;

        _chdir($cwd);

        die $e;
    };

    info sprintf "Done installing '%s'", $stew->package;
    $self->{snapshot}->mark_installed($stew, $tree);

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
    _chdir($stew->package . '-dist');

    my $tree = _tree(".");
    foreach my $file (@$tree) {
        my $basename = basename $file;
        _copy($file, "$ENV{PREFIX}/$basename");
    }

    return $tree;
}

sub _install_from_source {
    my $self = shift;
    my ($stew) = @_;

    info sprintf "Preparing '%s'...", $stew->package;
    $self->_prepare($stew);

    info sprintf "Building '%s'...", $stew->package;
    $self->_build($stew);

    _mkpath($ENV{PREFIX});

    my $orig_tree = _tree $ENV{PREFIX};

    info sprintf "Installing '%s'...", $stew->package;
    $self->_install($stew);

    info "Calculating tree difference";
    my $new_tree = _tree $ENV{PREFIX};
    my $tree_diff = _tree_diff $orig_tree, $new_tree;

    my $dist_name = sprintf '%s-dist', $stew->package;
    _mkpath $dist_name;

    foreach my $path (@$tree_diff) {
        my $rel_filename = $path;
        $rel_filename =~ s#^$ENV{PREFIX}/?##;

        my $dest_path = "$dist_name/$rel_filename";
        _mkpath dirname $dest_path;
        _copy $path, $dest_path;
    }

    my $dist_archive = "$dist_name.tar.gz";
    cmd("tar czf $dist_archive $dist_name");

    info sprintf "Caching '%s' as '$dist_archive'...", $stew->package;
    $self->{cache}->cache_dist("$dist_archive");

    return $tree_diff;
}

sub _prepare {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    my $src_file = $self->{cache}->get_src_filepath($stew);

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
    my ($stew) = @_;

    my $build_dir = $self->{build_dir};
    my $work_dir = File::Spec->catfile($build_dir, $stew->package);

    my @makedepends = $stew->makedepends;
    if (@makedepends) {
        info "Found make dependencies: @makedepends";
    }
    foreach my $makedepends (@makedepends) {
        my $stew_file = $self->{cache}->get_stew_filepath($makedepends);
        my $stew      = App::stew::file->parse($stew_file);

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

    my @depends = $stew->depends;
    if (@depends) {
        info "Found dependencies: @depends";
    }
    foreach my $depends (@depends) {
        my $stew_file = $self->{cache}->get_stew_filepath($depends);
        my $stew      = App::stew::file->parse($stew_file);

        _chdir($self->{root_dir});

        $self->build($stew);

        _chdir($self->{root_dir});
    }
}

1;
