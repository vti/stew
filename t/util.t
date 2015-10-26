use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use App::stew::util qw(_tree _tree_diff);

subtest '_tree: returns file tree' => sub {
    my $tmp_dir = tempdir(CLEANUP => 1);

    _write_file("$tmp_dir/file",         "hello");
    _write_file("$tmp_dir/dir/file",     "hello");
    _write_file("$tmp_dir/dir/dir/file", "hello");

    my $tree = _tree($tmp_dir, $tmp_dir);

    is_deeply $tree, ['/dir/dir/file', '/dir/file', '/file'];
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

sub _write_file {
    my ($path, $content) = @_;

    mkpath dirname $path;

    open my $fh, '>', $path or die $!;
    print $fh $content;
    close $fh;
}

done_testing;
