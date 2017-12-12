package App::stew::cmd::install;

use strict;
use warnings;

use base 'App::stew::cmd::base';

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
    my $opt_stewfile;
    my $opt_help;
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
        "stewfile=s"            => \$opt_stewfile,
        "help"                  => \$opt_help,
    ) or die "error";

    if ($opt_help) {
        App::stew::cmd::help->new->run('install');
        return;
    }

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

    my $snapshot = App::stew::snapshot->new(base => $opt_base, prefix => $opt_prefix);
    $snapshot->load;

    my $local_settings = $snapshot->local_settings;

    my $os_forced = !!$opt_os;
    $opt_os   ||= $local_settings->{os}   || App::stew::env->detect_os;
    $opt_arch ||= $local_settings->{arch} || App::stew::env->detect_arch;

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

    if (   !$os_forced
        && !$opt_force_platform
        && !$opt_from_source
        && !$local_settings->{os}
        && !$local_settings->{arch})
    {
        if (!$index->platform_available($opt_os, $opt_arch)) {
            my $platforms = $index->list_platforms;

            warn "Platform '$platform' is not available. "
              . "Maybe you want --from-source or --force-platform?\n";
            if (@$platforms) {
                warn "Available platforms are: \n\n";
                warn join("\n",
                    map { "    --os $_->{os} --arch $_->{arch}" } @$platforms)
                  . "\n\n";
            }
            else {
                warn "No platforms available\n\n";
            }

            error 'Fail to detect platform';
        }
    }

    if ($opt_stewfile || (@argv == 1 && $argv[0] eq '.')) {
        my $stewfile = abs_path($opt_stewfile // 'stewfile');

        die "stewfile '$stewfile' not found\n" unless -f $stewfile;

        @argv = grep { $_ && !/^#/ } split /(?:\r?\n)+/, slurp_file($stewfile);
    }

    if (!@argv) {
        info 'Nothing to install';
        return;
    }

    $ENV{STEW_OS}   = $opt_os;
    $ENV{STEW_ARCH} = $opt_arch;
    $ENV{PREFIX}    = File::Spec->catfile($opt_base, $opt_prefix);

    my @trees;
    foreach my $package (@argv) {
        my $resolved = $index->resolve($package);

        error sprintf "Unknown package '%s'", $package unless $resolved;

        if (!$opt_reinstall && $snapshot->is_up_to_date($resolved)) {
            info sprintf "'%s' is up to date", $resolved;
            next;
        }

        my $tree = App::stew::tree->new(repo => $repo, index => $index);
        my $dump = $tree->build($package);

        push @trees, $dump;
    }

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
__END__

=head1 NAME

stew install - install package

=head1 SYNOPSIS

stew install [options ...]

Options:

    --base                   base directory
    --prefix                 prefix (default 'local')
    --repo                   path/URL to repository
    --build                  build directory (default './build')

    --reinstall              reinstall package
    --from-source            force installing package from source
    --from-source-recursive  force installing package and its dependencies from source

    --force-platform         force detected platform
    --os                     OS name (default autodetect)
    --arch                   architecture (default autodetect)

    --dry-run                do not really install anything
    --keep-files             do not remove temporary files after installation
    --cache                  use only cached files
    --verbose                verbose mode

=head1 OPTIONS

=over 4

=item B<--base>

Print a brief help message and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut
