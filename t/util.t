use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use App::stew::util qw(_tree _tree_diff sort_by_version);

subtest '_tree: returns file tree' => sub {
    my $tmp_dir = tempdir(CLEANUP => 1);

    _write_file("$tmp_dir/file",         "hello");
    _write_file("$tmp_dir/dir/file",     "hello");
    _write_file("$tmp_dir/dir/dir/file", "hello");

    my $tree = _tree($tmp_dir, $tmp_dir);

    is_deeply $tree, ['dir/dir/file', 'dir/file', 'file'];
};

subtest '_tree_diff: returns diff' => sub {
    is_deeply _tree_diff([], []), [];
    is_deeply _tree_diff([], ['foo']), ['foo'];
    is_deeply _tree_diff(['foo'], ['foo']), [];
    is_deeply _tree_diff(['foo'], ['bar']), ['bar'];
    is_deeply _tree_diff(['foo'], ['foo', 'bar']), ['bar'];
    is_deeply _tree_diff(['foo', 'bar'], []), [];
    is_deeply _tree_diff(['foo', 'bar'], ['foo', 'baz']), ['baz'];
    is_deeply _tree_diff(['foo', 'bar'], ['foo', 'bar', 'baz']), ['baz'];

    is_deeply _tree_diff(['foo', 'bar'],
        ['other', 'other', 'foo', 'other', 'other', 'bar']),
      ['other', 'other', 'other', 'other'];
};

subtest 'sort_by_version: sorts by version' => sub {
    is_deeply [sort_by_version()], [];
    is_deeply [sort_by_version('foo_1.2.stew', 'foo_1.3.stew')], ['foo_1.2.stew', 'foo_1.3.stew'];
    is_deeply [sort_by_version('foo_1.1.1.stew', 'foo_1.1.stew')],
      ['foo_1.1.stew', 'foo_1.1.1.stew'];
    is_deeply [sort_by_version('foo-1.stew',   'foo-2.stew')], ['foo-1.stew', 'foo-2.stew'];
    is_deeply [sort_by_version('foo-1p1.stew', 'foo-1.stew')], ['foo-1.stew', 'foo-1p1.stew'];
    is_deeply [sort_by_version('foo_0.29.1.stew', 'foo_0.29.stew')],
      ['foo_0.29.stew', 'foo_0.29.1.stew'];

    is_deeply [sort_by_version('class-c3-perl-1.2.4.tar.gz', 'class-c3-perl-1.2.3.tar.gz')],
      ['class-c3-perl-1.2.3.tar.gz', 'class-c3-perl-1.2.4.tar.gz'];

    is_deeply [sort_by_version('zip30.tar.gz', 'zip20.tar.gz')],
      ['zip20.tar.gz', 'zip30.tar.gz'];

    is_deeply [sort_by_version('libjpg_9b.stew', 'libjpg_8b.stew')],
      ['libjpg_8b.stew', 'libjpg_9b.stew'];

    is_deeply [
        sort_by_version(
            'libyaml-libyaml-perl_0.63_001.stew',
            'libyaml-libyaml-perl_0.59.stew',
            'libyaml-libyaml-perl_0.63.stew',
        )
      ],
      [
        'libyaml-libyaml-perl_0.59.stew',
        'libyaml-libyaml-perl_0.63.stew',
        'libyaml-libyaml-perl_0.63_001.stew'
      ];

    is_deeply [sort_by_version('dist/linux-centos-7/x86', 'dist/linux-centos-6/x86')],
      ['dist/linux-centos-6/x86', 'dist/linux-centos-7/x86'];
};

sub _write_file {
    my ($path, $content) = @_;

    mkpath dirname $path;

    open my $fh, '>', $path or die $!;
    print $fh $content;
    close $fh;
}

done_testing;
