use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use App::stew::snapshot;

subtest 'is_installed: returns false when empty' => sub {
    my $snapshot = _build_snapshot();

    is $snapshot->is_installed('foo'), 0;
};

subtest 'is_installed: returns true when installed' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->mark_installed(
        name    => 'foo',
        version => '1.0',
        files   => ['foo']
    );

    is $snapshot->is_installed('foo'), 1;
};

subtest 'is_up_to_date: returns true when installed' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->mark_installed(
        name    => 'foo',
        version => '1.0',
        files   => ['foo']
    );

    is $snapshot->is_up_to_date('foo', '1.0'), 1;
};

subtest 'is_up_to_date: returns false when not installed' => sub {
    my $snapshot = _build_snapshot();

    is $snapshot->is_up_to_date('foo', '1.0'), 0;
};

subtest 'is_up_to_date: returns false when not old version' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->mark_installed(
        name    => 'foo',
        version => '1.0',
        files   => ['foo']
    );

    is $snapshot->is_up_to_date('foo', '1.2'), 0;
};

subtest 'mark_installed: sets package to installed' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->mark_installed(
        name    => 'foo',
        version => '1.0',
        files   => ['foo']
    );

    is $snapshot->is_installed('foo'), 1;
};

subtest 'mark_uninstalled: sets package to uninstalled' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->mark_installed(
        name    => 'foo',
        version => '1.0',
        files   => ['foo']
    );
    $snapshot->mark_uninstalled('foo');

    is $snapshot->is_installed('foo'), 0;
};

subtest 'local_settings: returns local settings' => sub {
    my $snapshot = _build_snapshot();

    $snapshot->local_settings->{foo} = 'bar';
    $snapshot->store;

    $snapshot->load;

    is $snapshot->local_settings->{foo}, 'bar';
};

done_testing;

sub _build_snapshot {
    my (%params) = @_;

    return App::stew::snapshot->new(
        base => $params{base} || tempdir(CLEANUP => 1),
        %params
    );
}
