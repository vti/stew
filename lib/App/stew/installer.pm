package App::stew::installer;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Carp qw(croak);
use File::Path qw(rmtree);
use File::Basename qw(basename dirname);
use App::stew::builder;
use App::stew::util
  qw(cmd info debug error _chdir _mkpath _rmtree _copy _unlink _tree _tree_diff);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{base}      = $params{base};
    $self->{root_dir}  = $params{root_dir};
    $self->{build_dir} = $params{build_dir};
    $self->{repo}      = $params{repo};
    $self->{snapshot}  = $params{snapshot};

    $self->{from_source}           = $params{from_source};
    $self->{from_source_recursive} = $params{from_source_recursive};
    $self->{reinstall}             = $params{reinstall};
    $self->{keep_files}            = $params{keep_files};
    $self->{cache}                 = $params{cache};

    return $self;
}

sub install {
    my $self = shift;
    my ($stew_tree, %options) = @_;

    my $is_dependency = !!$options{satisfies};

    my $stew = $stew_tree->{stew};

    my $reinstall = !$is_dependency && $self->{reinstall};
    my $from_source =
      $self->{from_source_recursive} || (!$is_dependency && $self->{from_source});

    if (  !$reinstall
        && $self->{snapshot}->is_up_to_date($stew->name, $stew->version))
    {
        debug sprintf "'%s' is up to date", $stew->package;
        return;
    }
    elsif ($self->{snapshot}->is_installed($stew->name)) {
        my $uninstaller = App::stew::uninstaller->new(base => $self->{base});
        $uninstaller->uninstall($stew->name);
    }

    croak '$ENV{PREFIX} not defined' unless $ENV{PREFIX};

    _mkpath($ENV{PREFIX});

    debug sprintf "Building & installing '%s'...", $stew->package;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _rmtree $work_dir;
    _mkpath($work_dir);

    my $cwd  = getcwd();
    my $tree = [];
    my @depends;
    eval {
        if (my @os = $stew->os) {
            my $match = 0;

            foreach my $os (@os) {
                if ($ENV{STEW_OS} =~ m/$os/) {
                    $match = 1;
                    last;
                }
            }

            if (!$match) {
                info sprintf "Not supported OS '%s'. Supported are '%s'. Skipping...",
                  $ENV{STEW_OS}, join(', ', @os);
                return $self;
            }
        }

        # This is to avoid recursive dependencies
        $self->{snapshot}->mark_installed(
            name    => $stew->name,
            version => $stew->version,
            files   => $tree,
            depends => [
                map { {name => $_->{stew}->name, version => $_->{stew}->version} }
                  @depends
            ],
            $is_dependency ? (dependency => 1) : (),
            fake => 1
        );

        debug "Resolving dependencies...";
        @depends = $self->_install_dependencies($stew, $stew_tree);

        if ($stew->is('cross-platform')) {
            debug 'Cross platform package';

            my $builder = $self->_build_builder;

            $tree = $builder->build($stew_tree);

            my $dist_path =
              $self->{repo}->mirror_dist_dest($stew->name, $stew->version);

            my $dist_archive = basename $dist_path;
            my ($dist_name) = $dist_archive =~ m/^(.*)\.tar\.gz$/;

            _chdir $work_dir;
            _chdir "$dist_name/$ENV{PREFIX}";

            cmd("cp -Ra * $ENV{PREFIX}/");
        }
        elsif ($stew->is('meta')) {
            debug 'Meta package';
        }
        else {
            my $dist_path =
              $self->{repo}->mirror_dist_dest($stew->name, $stew->version);

            eval { $self->{repo}->mirror_dist($stew->name, $stew->version) };

            if ($from_source || !-f $dist_path) {
                my $builder = $self->_build_builder;

                $tree = $builder->build($stew_tree);
            }

            $tree = $self->_install_from_binary($stew, $dist_path);
        }

        _chdir($cwd);
    } or do {
        my $e = $@;

        _chdir($cwd);

        die $e;
    };

    info sprintf "Done installing '%s'", $stew->package;
    $self->{snapshot}->mark_installed(
        name    => $stew->name,
        version => $stew->version,
        files   => $tree,
        depends => [
            map { {name => $_->{stew}->name, version => $_->{stew}->version} }
              @depends
        ],
        $is_dependency ? (dependency => 1) : ()
    );

    _rmtree $work_dir unless $self->{keep_files};

    return $self;
}

sub _install_from_binary {
    my $self = shift;
    my ($stew, $dist_path) = @_;

    debug sprintf "Installing '%s' from binaries '%s'...", $stew->package,
      $dist_path;

    my $basename = basename $dist_path;

    my $work_dir = File::Spec->catfile($self->{build_dir}, $stew->package);
    _chdir $work_dir;

    my ($dist_name) = $basename =~ m/^(.*)\.tar\.gz$/;
    _rmtree $dist_name;
    _mkpath $dist_name;

    _copy($dist_path, "$dist_name/$basename");
    _chdir $dist_name;
    cmd("tar xzf $basename");
    _unlink $basename;

    cmd("cp -Ra * $ENV{PREFIX}/");

    return _tree(".", ".");
}

sub _install_dependencies {
    my $self = shift;
    my ($stew, $tree) = @_;

    my @depends = @{$tree->{dependencies} || []};
    if (@depends) {
        debug "Found dependencies: "
          . join(', ', map { $_->{stew}->package } @depends);
    }

    foreach my $tree (@depends) {
        my $stew = $tree->{stew};

        _chdir($self->{root_dir});

        $self->install($tree, satisfies => $stew);

        _chdir($self->{root_dir});
    }

    return @depends;
}

sub _build_builder {
    my $self = shift;

    return App::stew::builder->new(
        root_dir  => $self->{root_dir},
        build_dir => $self->{build_dir},
        repo      => $self->{repo},
        snapshot  => $self->{snapshot},
    );
}

1;
