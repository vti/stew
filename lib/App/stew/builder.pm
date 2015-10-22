package App::stew::builder;

use strict;
use warnings;

use Cwd qw(getcwd);
use Carp qw(croak);
use File::Path qw(rmtree);
use File::Basename qw(basename);
use App::stew::util qw(cmd info debug error _chdir _mkpath _copy _unlink);

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
    eval {
        _mkpath($work_dir);
        _chdir($work_dir);

        info sprintf "Resolving dependencies...", $stew->package;
        $self->_resolve_dependencies($stew);

        my $dist_path = $self->{cache}->get_dist_filepath($stew);
        if (-f $dist_path) {
            $self->_install_from_binary($stew, $dist_path);
        }
        else {
            $self->_install_from_source($stew);
        }

        _chdir($cwd);
    } or do {
        my $e = $@;

        _chdir($cwd);

        die $e;
    };

    info sprintf "Done installing '%s'", $stew->package;
    $self->{snapshot}->mark_installed($stew);

    return $self;
}

sub _install_from_binary {
    my $self = shift;
    my ($stew, $dist_path) = @_;

    my $basename = basename $dist_path;

    cmd("cp $dist_path .");
    cmd("tar xzf $basename");
    _chdir($stew->package);

    info sprintf "Installing from binary '%s'...", $stew->package;
    $self->_install($stew);

    return $self;
}

sub _install_from_source {
    my $self = shift;
    my ($stew) = @_;

    info sprintf "Preparing '%s'...", $stew->package;
    $self->_prepare($stew);

    info sprintf "Building '%s'...", $stew->package;
    $self->_build($stew);

    _mkpath($ENV{PREFIX});
    cmd("mv $ENV{PREFIX} $ENV{PREFIX}_");
    _mkpath($ENV{PREFIX});

    eval {
        info sprintf "Installing '%s'...", $stew->package;
        $self->_install($stew);

        my $dist_name = sprintf '%s-dist.tar.gz', $stew->package;
        cmd("cd $ENV{PREFIX}; tar czf $dist_name *");

        info sprintf "Caching '%s' as '$dist_name'...", $stew->package;
        $self->{cache}->cache_dist("$ENV{PREFIX}/$dist_name");

        _unlink "$ENV{PREFIX}/$dist_name";

        cmd("cp --remove-destination -R $ENV{PREFIX}/* $ENV{PREFIX}_/");
    };

    rmtree($ENV{PREFIX});
    cmd("mv $ENV{PREFIX}_ $ENV{PREFIX}");

    die $@ if $@;

    return $self;
}

sub _prepare {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir($work_dir);

    my $src_file = $self->{cache}->get_src_filepath($stew);

    _copy($src_file, $work_dir) or error("Copy '$src_file' to '$work_dir' failed: $!");

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
