use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use App::stew::repo;
use App::stew::index;
use App::stew::tree;

subtest 'builds no deps tree' => sub {
    my $tree = _build_tree();

    my $dump = $tree->build('single');

    ok ref $dump->{stew};
    is_deeply $dump->{dependencies},      [];
    is_deeply $dump->{make_dependencies}, [];
};

subtest 'builds tree with deps' => sub {
    my $tree = _build_tree();

    my $dump = $tree->build('with-deps');

    ok ref $dump->{stew};
    ok ref $dump->{dependencies}->[0]->{stew};
    is_deeply $dump->{make_dependencies}, [];
};

subtest 'flattens deps' => sub {
    my $tree = _build_tree();

    my $dump = $tree->build('with-deps');

    my @list = $tree->flatten($dump);

    is $list[0]->package, 'single-1.0';
    is $list[1]->package, 'with-deps-1.0';
};

done_testing;

sub _build_index {
    my (%params) = @_;

    return App::stew::index->new(%params);
}

sub _build_repo {
    my (%params) = @_;

    return App::stew::repo->new(
        os          => 'linux',
        arch        => 'x86_64',
        path        => 't/repo',
        mirror_path => tempdir(CLEANUP => 1),
        %params
    );
}

sub _build_tree {
    my (%params) = @_;

    my $repo = _build_repo();
    my $index = _build_index(repo => $repo);

    return App::stew::tree->new(
        repo => $repo,
        index => $index,
        %params
    );
}
