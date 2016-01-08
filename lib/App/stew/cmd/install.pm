package App::stew::cmd::install;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use Cwd qw(cwd abs_path);
use File::Path qw(mkpath);
use File::Spec;
use App::stew::repo;
use App::stew::installer;
use App::stew::snapshot;
use App::stew::index;
use App::stew::tree;
use App::stew::env;
use App::stew::util qw(info debug error slurp_file);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_base;
    my $opt_prefix = 'local';
    my $opt_repo;
    my $opt_os;
    my $opt_arch;
    my $opt_build = 'build';
    my $opt_dry_run;
    my $opt_verbose;
    my $opt_from_source;
    my $opt_from_source_recursive;
    my $opt_reinstall;
    my $opt_keep_files;
    GetOptionsFromArray(
        \@argv,
        "base=s"                => \$opt_base,
        "prefix=s"              => \$opt_prefix,
        "repo=s"                => \$opt_repo,
        "os=s"                  => \$opt_os,
        "arch=s"                => \$opt_arch,
        "build=s"               => \$opt_build,
        "dry-run"               => \$opt_dry_run,
        "verbose"               => \$opt_verbose,
        "from-source"           => \$opt_from_source,
        "from-source-recursive" => \$opt_from_source_recursive,
        "reinstall"             => \$opt_reinstall,
        "keep-files"            => \$opt_keep_files,
    ) or die "error";

    $opt_os   //= App::stew::env->detect_os;
    $opt_arch //= App::stew::env->detect_arch;

    error("--base is required") unless $opt_base;
    error("--repo is required") unless $opt_repo;

    mkpath($opt_base);
    $opt_base = abs_path($opt_base);

    my $root_dir  = abs_path(cwd());
    my $build_dir = abs_path($opt_build);
    mkpath($build_dir);

    $ENV{STEW_LOG_LEVEL} = $opt_verbose ? 1 : 0;
    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    unlink $ENV{STEW_LOG_FILE};

    my $repo = App::stew::repo->new(
        path        => $opt_repo,
        mirror_path => "$build_dir/.cache",
        os          => $opt_os,
        arch        => $opt_arch
    );

    my $index = App::stew::index->new(repo => $repo);

    my $snapshot = App::stew::snapshot->new(base => $opt_base);
    $snapshot->load;

    if (@argv == 1 && $argv[0] eq '.') {
        die 'stewfile not found' unless -f 'stewfile';

        @argv = grep { $_ && !/^#/ } split /\n+/, slurp_file('stewfile');
    }

    my @trees;
    foreach my $package (@argv) {
        my $tree = App::stew::tree->new(repo => $repo, index => $index);
        my $dump = $tree->build($package);

        push @trees, $dump;
    }

    $ENV{STEW_OS}   = $opt_os;
    $ENV{STEW_ARCH} = $opt_arch;
    $ENV{PREFIX}    = File::Spec->catfile($opt_base, $opt_prefix);

    App::stew::env->setup;

    my $builder = App::stew::installer->new(
        base                  => $opt_base,
        root_dir              => $root_dir,
        build_dir             => $build_dir,
        repo                  => $repo,
        snapshot              => $snapshot,
        from_source           => $opt_from_source,
        from_source_recursive => $opt_from_source_recursive,
        reinstall             => $opt_reinstall,
        keep_files            => $opt_keep_files,
    );

    foreach my $tree (@trees) {
        $builder->build($tree);
    }

    info "Done";
}

1;
