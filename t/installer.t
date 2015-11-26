use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Copy qw(copy);
use Cwd qw(abs_path);
use App::stew::file;
use App::stew::snapshot;
use App::stew::installer;
use App::stew::repo;

subtest 'installs from source' => sub {
    my $root_dir = tempdir(CLEANUP => 1);
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    my $builder = _build_builder(
        from_source => 1,
        base_dir  => $base_dir,
        root_dir  => $root_dir,
        build_dir => $build_dir
    );

    my $stew = App::stew::file->parse("t/repo/stew/single_1.0.stew");

    $builder->build({stew => $stew});

    ok -f "$base_dir/local/foo";
    ok -f "$base_dir/stew.snapshot";
};

subtest 'caches binary' => sub {
    my $root_dir = tempdir(CLEANUP => 1);
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    my $builder = _build_builder(
        from_source => 1,
        base_dir    => $base_dir,
        root_dir    => $root_dir,
        build_dir   => $build_dir
    );

    my $stew = App::stew::file->parse("t/repo/stew/single_1.0.stew");

    $builder->build({stew => $stew});

    ok -f "$build_dir/.cache/dist/linux/x86_64/single_1.0_linux-x86_64.tar.gz";
};

subtest 'installs from dist when available' => sub {
    my $root_dir = tempdir(CLEANUP => 1);
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    my $builder = _build_builder(
        base_dir    => $base_dir,
        root_dir    => $root_dir,
        build_dir   => $build_dir
    );

    my $stew = App::stew::file->parse("t/repo/stew/single_1.0.stew");

    $builder->build({stew => $stew});

    unlink("$build_dir/.cache/src/single-1.0.tar.gz");

    $builder->build({stew => $stew});

    ok -f "$base_dir/local/foo";
    ok -f "$base_dir/stew.snapshot";
};

done_testing;

sub _copy {
    my ($from, $to) = @_;

    mkpath dirname $to;
    copy($from, $to);
}

sub _build_builder {
    my (%params) = @_;

    App::stew::installer->new(
        root_dir  => $params{root_dir},
        build_dir => $params{build_dir},
        snapshot  => App::stew::snapshot->new(base => $params{base_dir}),
        repo      => App::stew::repo->new(
            path        => abs_path("t/repo"),
            mirror_path => "$params{build_dir}/.cache",
            os          => 'linux',
            arch        => 'x86_64'
        ),
        %params
    );
}
