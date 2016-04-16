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
    my $opt_repo   = $ENV{STEW_REPO};
    my $opt_force_platform;
    my $opt_os;
    my $opt_arch;
    my $opt_build = 'build';
    my $opt_dry_run;
    my $opt_verbose;
    my $opt_from_source;
    my $opt_from_source_recursive;
    my $opt_reinstall;
    my $opt_keep_files;
    my $opt_cache;
    GetOptionsFromArray(
        \@argv,
        "base=s"                => \$opt_base,
        "prefix=s"              => \$opt_prefix,
        "repo=s"                => \$opt_repo,
        "force-platform"        => \$opt_force_platform,
        "os=s"                  => \$opt_os,
        "arch=s"                => \$opt_arch,
        "build=s"               => \$opt_build,
        "dry-run"               => \$opt_dry_run,
        "verbose"               => \$opt_verbose,
        "from-source"           => \$opt_from_source,
        "from-source-recursive" => \$opt_from_source_recursive,
        "reinstall"             => \$opt_reinstall,
        "keep-files"            => \$opt_keep_files,
        "cache"                 => \$opt_cache,
    ) or die "error";

    error("--base is required") unless $opt_base;
    error("--repo is required") unless $opt_repo;

    mkpath($opt_base);
    $opt_base = abs_path($opt_base);

    mkpath($opt_build);
    my $root_dir  = abs_path(cwd());
    my $build_dir = abs_path($opt_build);

    $ENV{STEW_LOG_LEVEL} = $opt_verbose ? 1 : 0;
    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    unlink $ENV{STEW_LOG_FILE};

    my $snapshot = App::stew::snapshot->new(base => $opt_base);
    $snapshot->load;

    my $local_settings = $snapshot->local_settings;

    $opt_os   //= $local_settings->{os}   // App::stew::env->detect_os;
    $opt_arch //= $local_settings->{arch} // App::stew::env->detect_arch;

    my $repo = App::stew::repo->new(
        path        => $opt_repo,
        mirror_path => "$build_dir/.cache",
        os          => $opt_os,
        arch        => $opt_arch,
        cache       => $opt_cache,
    );

    my $index = App::stew::index->new(repo => $repo);

    my $platform = "$opt_os-$opt_arch";

    warn "Installing for '$platform'\n";

    if (   !$opt_force_platform
        && !$opt_from_source
        && !$local_settings->{os}
        && !$local_settings->{arch})
    {
        if (!$index->platform_available($opt_os, $opt_arch)) {
            my $platforms = $index->list_platforms;

            warn "Platform '$platform' is not available. "
              . "Maybe you want --from-source or --force-platform?\n";
            warn "Available platforms are: \n\n";
            warn join("\n",
                map { "    --os $_->{os} --arch $_->{arch}" } @$platforms)
              . "\n\n";

            error 'Fail to detect platform';
        }
    }

    if (@argv == 1 && $argv[0] eq '.') {
        die 'stewfile not found' unless -f 'stewfile';

        @argv = grep { $_ && !/^#/ } split /\n+/, slurp_file('stewfile');
    }

    my @trees;
    foreach my $package (@argv) {
        my $resolved = $index->resolve($package);

        if (!$opt_reinstall && $snapshot->is_up_to_date($resolved)) {
            info sprintf "'%s' is up to date", $resolved;
            next;
        }

        my $tree = App::stew::tree->new(repo => $repo, index => $index);
        my $dump = $tree->build($package);

        push @trees, $dump;
    }

    $ENV{STEW_OS}   = $opt_os;
    $ENV{STEW_ARCH} = $opt_arch;
    $ENV{PREFIX}    = File::Spec->catfile($opt_base, $opt_prefix);

    App::stew::env->new(prefix => $ENV{PREFIX})->setup;

    my $installer = App::stew::installer->new(
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
        $installer->install($tree);
    }

    $snapshot->local_settings->{os}   = $opt_os;
    $snapshot->local_settings->{arch} = $opt_arch;
    $snapshot->store;

    info "Done";
}

1;
