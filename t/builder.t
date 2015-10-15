use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use App::stew::snapshot;
use App::stew::builder;
use App::stew::cache;

my $STEW = <<'EOF';
$name    = "package";
$version = "1.0";
$package = "$name-$version";
$file    = "$package";

prepare {

};

build {

};

install {
    "cp $package $ENV{PREFIX}"
};
EOF

subtest 'installs ' => sub {
    my $root_dir = tempdir();
    warn $root_dir;
    my $build_dir = "$root_dir/build";
    my $base_dir  = "$root_dir/opt";

    mkpath $build_dir;
    mkpath $base_dir;

    $ENV{STEW_LOG_FILE} = "$build_dir/stew.log";
    $ENV{PREFIX}        = "$base_dir/local";

    _write_file("$build_dir/.cache/src/package-1.0",   'archive');
    _write_file("$build_dir/.cache/stew/package.stew", $STEW);

    my $builder = _build_builder(
        base_dir  => $base_dir,
        root_dir  => $root_dir,
        build_dir => $build_dir
    );

    my $stew = App::stew::file->parse("$build_dir/.cache/stew/package.stew");

    $builder->build($stew);

    ok -f "$base_dir/local/package-1.0";
    ok -f "$base_dir/stew.snapshot";
};

done_testing;

sub _write_file {
    my ($file, $content) = @_;

    mkpath dirname $file;

    open my $fh, '>', $file or die $!;
    print $fh $content;
    close $fh;
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
