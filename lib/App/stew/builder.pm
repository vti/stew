package App::stew::builder;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Carp qw(croak);
use File::Path qw(rmtree);
use File::Basename qw(basename dirname);
use App::stew::util
  qw(cmd info debug error _chdir _mkpath _copy _rmtree _tree);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root_dir}  = $params{root_dir};
    $self->{build_dir} = $params{build_dir};
    $self->{repo}      = $params{repo};
    $self->{snapshot}  = $params{snapshot};

    return $self;
}

sub build {
    my $self = shift;
    my ($stew_tree, $mode) = @_;

    my $stew = $stew_tree->{stew};

    croak '$ENV{PREFIX} not defined' unless $ENV{PREFIX};

    _mkpath($ENV{PREFIX});

    info sprintf "Building '%s'...", $stew->package;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);

    my $cwd = getcwd();
    my $tree = [];
    eval {
        _rmtree $work_dir;
        _mkpath($work_dir);
        _chdir($work_dir);

        info sprintf "Checking dependencies...", $stew->package;
        $self->_resolve_dependencies($stew, $stew_tree);

        my $dist_path = $self->{repo}->mirror_dist_dest($stew->name, $stew->version);

        my $dist_archive = basename $dist_path;
        my ($dist_name) = $dist_archive =~ m/^(.*)\.tar\.gz$/;

        $self->_build_from_source($stew, $dist_name);

        cmd("tar czhf $dist_archive -C $dist_name/$ENV{PREFIX}/ .");

        info sprintf "Saving '%s' as '$dist_path'...", $stew->package;
        _mkpath(dirname $dist_path);
        _copy $dist_archive, $dist_path;

        _chdir($cwd);
    } or do {
        my $e = $@;

        _chdir($cwd);

        die $e;
    };

    return $self;
}

sub _build_from_source {
    my $self = shift;
    my ($stew, $dist_name) = @_;

    _mkpath($ENV{PREFIX});
    _mkpath $dist_name;
    $ENV{DESTDIR} = abs_path($dist_name);

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _mkpath $work_dir;
    _chdir($work_dir);

    my $src_file = $self->{repo}->mirror_src($stew->file);
    _copy($src_file, $work_dir);

    info sprintf "Preparing '%s'...", $stew->package;
    $self->_run_stew_phase($stew, 'prepare');

    info sprintf "Building '%s'...", $stew->package;
    $self->_run_stew_phase($stew, 'build');

    info sprintf "Installing '%s'...", $stew->package;
    $self->_run_stew_phase($stew, 'install');

    info sprintf "Cleaning '%s'...", $stew->package;
    $self->_run_stew_phase($stew, 'cleanup');

    return $self;
}

sub _run_stew_phase {
    my $self = shift;
    my ($stew, $phase) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    my @commands = $stew->run($phase);
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
    foreach my $tree (@depends) {
        my $stew = $tree->{stew};

        die $stew->package . " is not installed\n"
          unless $self->{snapshot}->is_up_to_date($stew->name, $stew->version);
    }
}

1;
