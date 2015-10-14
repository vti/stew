package App::stew::builder;

use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);
use App::stew::util qw(cmd info debug);

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
        info sprintf "'%s' is up to date\n", $stew->package;
        return;
    }

    info sprintf "Building & installing '%s'...\n", $stew->package;

    mkpath($ENV{PREFIX});

    info sprintf "Resolving dependencies...\n", $stew->package;

    $self->_resolve_dependencies($stew);

    info sprintf "Preparing '%s'...\n", $stew->package;
    $self->_prepare($stew);

    info sprintf "Building '%s'...\n", $stew->package;
    $self->_build($stew);

    cmd("mv $ENV{PREFIX} $ENV{PREFIX}_");

    eval {
        mkpath($ENV{PREFIX});

        info sprintf "Installing '%s'...\n", $stew->package;
        $self->_install($stew);

        my $dist_name = sprintf '%s-dist.tar.gz', $stew->package;
        cmd("cd $ENV{PREFIX}; tar czf $dist_name *");

        info sprintf "Caching '%s'...\n", $stew->package;
        $self->{cache}->cache_dist("$ENV{PREFIX}/$dist_name");

        cmd("cp -R $ENV{PREFIX}/* $ENV{PREFIX}_/");
        rmtree($ENV{PREFIX});
    };

    cmd("mv $ENV{PREFIX}_ $ENV{PREFIX}");

    if (!$@) {
        info sprintf "Done installing '%s'\n", $stew->package;
        $self->{snapshot}->mark_installed($stew);
    }

    return $self;
}

sub _prepare {
    my $self = shift;
    my ($stew) = @_;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);

    #warn "Creating '$work_dir'";
    mkpath($work_dir);
    chdir($work_dir);

    my $src_file = $self->{cache}->get_src_filepath($stew);

    #warn "Copying '$src_file' to '$work_dir'";
    copy($src_file, $work_dir);

    my @commands = $stew->run('prepare');
    cmd(@commands);
}

sub _build {
    my $self = shift;
    my ($stew) = @_;

    my @commands = $stew->run('build');
    cmd(@commands);
}

sub _install {
    my $self = shift;
    my ($stew) = @_;

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
        info "Found make dependencies: @makedepends\n";
    }
    foreach my $makedepends (@makedepends) {
        my $stew_file = $self->{cache}->get_stew_filepath($makedepends);
        my $stew      = App::stew::file->parse($stew_file);

        chdir $self->{root_dir};

        info sprintf "Preparing make dependency '%s'\n", $stew->package;
        $self->_prepare($stew);

        chdir $self->{root_dir};

        if (!-e sprintf '%s/%s', $work_dir, $stew->package) {
            cmd(sprintf "ln -s $build_dir/%s/%s $work_dir",
                $stew->package, $stew->package);
        }
    }

    my @depends = $stew->depends;
    if (@depends) {
        info "Found dependencies: @depends\n";
    }
    foreach my $depends (@depends) {
        my $stew_file = $self->{cache}->get_stew_filepath($depends);
        my $stew      = App::stew::file->parse($stew_file);

        chdir $self->{root_dir};

        $self->build($stew);

        chdir $self->{root_dir};
    }
}

1;
