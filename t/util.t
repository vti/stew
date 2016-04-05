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
    is_deeply [sort_by_version('foo_1.2', 'foo_1.3')], ['foo_1.2', 'foo_1.3'];
    is_deeply [sort_by_version('foo_1.1.1', 'foo_1.1')],
      ['foo_1.1', 'foo_1.1.1'];
    is_deeply [sort_by_version('foo-1',   'foo-2')], ['foo-1', 'foo-2'];
    is_deeply [sort_by_version('foo-1p1', 'foo-1')], ['foo-1', 'foo-1p1'];
    is_deeply [sort_by_version('foo_0.29.1.stew', 'foo_0.29.stew')],
      ['foo_0.29.stew', 'foo_0.29.1.stew'];
};

sub _write_file {
    my ($path, $content) = @_;

    mkpath dirname $path;

    open my $fh, '>', $path or die $!;
    print $fh $content;
    close $fh;
}

done_testing;
