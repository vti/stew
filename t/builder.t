use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Copy qw(copy);
use App::stew::snapshot;
use App::stew::builder;
use App::stew::cache;

subtest 'installs ' => sub {
    my $root_dir = tempdir(CLEANUP => 1);
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    _copy("t/data/package-1.0.tar.gz", "$build_dir/.cache/src/package-1.0.tar.gz");
    _copy("t/data/package-1.0.stew", "$build_dir/.cache/stew/package-1.0.stew");

    my $builder = _build_builder(
        base_dir  => $base_dir,
        root_dir  => $root_dir,
        build_dir => $build_dir
    );

    my $stew = App::stew::file->parse("$build_dir/.cache/stew/package-1.0.stew");

    $builder->build($stew);

    ok -f "$base_dir/local/foo";
    ok -f "$base_dir/stew.snapshot";
};

subtest 'installs from dist when available' => sub {
    my $root_dir = tempdir(CLEANUP => 1);
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    _copy("t/data/package-1.0-dist.tar.gz", "$build_dir/.cache/dist/linux/x86_64/package-1.0-dist.tar.gz");
    _copy("t/data/package-1.0.stew", "$build_dir/.cache/stew/package-1.0.stew");

    my $builder = _build_builder(
        base_dir  => $base_dir,
        root_dir  => $root_dir,
        build_dir => $build_dir
    );

    my $stew = App::stew::file->parse("$build_dir/.cache/stew/package-1.0.stew");

    $builder->build($stew);

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

    App::stew::builder->new(
        root_dir  => $params{root_dir},
        build_dir => $params{build_dir},
        snapshot  => App::stew::snapshot->new(base => $params{base_dir}),
        cache     => App::stew::cache->new(
            path => "$params{build_dir}",
            os   => 'linux',
            arch => 'x86_64'
        )
    );
}
