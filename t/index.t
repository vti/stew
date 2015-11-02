use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use App::stew::repo;
use App::stew::index;

subtest 'resolves to latest version' => sub {
    my $index = _build_index();

    is $index->resolve('single'), 'single_1.0';
};

subtest 'returns undef when unknown package' => sub {
    my $index = _build_index();

    ok !defined $index->resolve('what');
};

subtest 'resolves to exact version' => sub {
    my $index = _build_index();

    is $index->resolve('single==1.0'), 'single_1.0';
    is $index->resolve('single==0.8'), 'single_0.8';
};

subtest 'returns undef when unknown version' => sub {
    my $index = _build_index();

    ok !defined $index->resolve('single==2.0');
};

subtest 'resolves latest version when greater than' => sub {
    my $index = _build_index();

    is $index->resolve('single>0.8'), 'single_1.0';
};

subtest 'resolves latest version when greater or equals' => sub {
    my $index = _build_index();

    is $index->resolve('single>=1.0'), 'single_1.0';
};

done_testing;

sub _build_repo {
    my (%params) = @_;

    return App::stew::repo->new(os => 'linux', arch => 'x86_64', %params);
}

sub _build_index {
    my (%params) = @_;

    my $build = tempdir();

    my $repo = _build_repo(path => 't/repo', mirror_path => $build);

    return App::stew::index->new(repo => $repo);
}
