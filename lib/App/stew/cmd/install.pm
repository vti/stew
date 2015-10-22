package App::stew::cmd::install;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use Cwd qw(cwd abs_path);
use File::Path qw(mkpath);
use File::Spec;
use App::stew::repo;
use App::stew::cache;
use App::stew::builder;
use App::stew::snapshot;
use App::stew::env;
use App::stew::util qw(info debug error);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{argv} = $params{argv};

    return $self;
}

sub run {
    my $self = shift;

    my $opt_base;
    my $opt_prefix = 'local';
    my $opt_repo;
    my $opt_os;
    my $opt_arch;
    my $opt_build = 'build';
    my $opt_dry_run;
    my $opt_verbose;
    GetOptionsFromArray(
        $self->{argv},
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix,
        "repo=s"   => \$opt_repo,
        "os=s"     => \$opt_os,
        "arch=s"   => \$opt_arch,
        "build=s"  => \$opt_build,
        "dry-run"  => \$opt_dry_run,
        "verbose"  => \$opt_verbose,
    ) or die "error";

    chomp($opt_os //= `uname -s`);
    $opt_os = lc $opt_os;
    chomp($opt_arch //= `uname -m`);
    $opt_arch = lc $opt_arch;

    error("--base is required") unless $opt_base;
    error("--repo is required") unless $opt_repo;

    my (@packages) = @ARGV;

    my $root_dir  = abs_path(cwd());
    my $build_dir = abs_path($opt_build);
    mkpath($build_dir);

    my $repo = App::stew::repo->new(path => $opt_repo);
    my $cache = App::stew::cache->new(
        path => $build_dir,
        repo => $repo,
        os   => $opt_os,
        arch => $opt_arch
    );
    my $snapshot = App::stew::snapshot->new(base => $opt_base)->load;
    my $builder = App::stew::builder->new(
        root_dir  => $root_dir,
        build_dir => $build_dir,
        cache     => $cache,
        snapshot  => $snapshot
    );

    $ENV{STEW_LOG_LEVEL} = $opt_verbose ? 1 : 0;
    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    unlink $ENV{STEW_LOG_FILE};

    info "Updating local repository...";

    my @stew_pkgs;
    foreach my $package (@packages) {
        push @stew_pkgs, $cache->sync_stew($package);
    }

    unless (@stew_pkgs) {
        error "No packages were found";
    }

    $ENV{STEW_OS}   = $opt_os;
    $ENV{STEW_ARCH} = $opt_arch;
    $ENV{PREFIX}    = File::Spec->catfile($opt_base, $opt_prefix);

    App::stew::env->setup;

    foreach my $stew_pkg (@stew_pkgs) {
        $builder->build($stew_pkg);
    }

    info "Done";
}

1;
