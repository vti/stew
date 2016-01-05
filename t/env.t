use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use App::stew::util qw(write_file);
use App::stew::env;

subtest 'detects debian' => sub {
    my $root = tempdir(CLEANUP => 1);

    mkpath("$root/etc");
    write_file("$root/etc/debian_version", <<'EOF');
7.7
EOF

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-debian-7');
};

subtest 'detects SuSE' => sub {
    my $root = tempdir(CLEANUP => 1);

    mkpath("$root/etc");
    write_file("$root/etc/SuSE-release", <<'EOF');
SUSE Linux Enterprise Server 11 (x86_64)
VERSION = 11
PATCHLEVEL = 4
EOF

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-suse-11');
};

subtest 'detects CentOS' => sub {
    my $root = tempdir(CLEANUP => 1);

    mkpath("$root/etc");
    write_file("$root/etc/redhat-release", <<'EOF');
CentOS Linux release 7.1.1503 (Core) 
EOF

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-centos-7');
};

subtest 'detects RedHat' => sub {
    my $root = tempdir(CLEANUP => 1);

    mkpath("$root/etc");
    write_file("$root/etc/redhat-release", <<'EOF');
Red Hat Enterprise Linux Server release 7.1 (Maipo)
EOF

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-redhat-7');
};

subtest 'when no dist name available add generic' => sub {
    my $root = tempdir(CLEANUP => 1);

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-generic');
};

subtest 'when no version available do not add anything' => sub {
    my $root = tempdir(CLEANUP => 1);

    mkpath("$root/etc");
    write_file("$root/etc/debian_version", <<'EOF');
EOF

    my $env = _build_env(root => $root, osname => 'linux');

    is($env->detect_os, 'linux-debian');
};

done_testing;

sub _build_env {
    my (%params) = @_;

    my $env = App::stew::env->new;

    $env = Test::MonkeyMock->new($env);
    $env->mock(_root   => sub { "$params{root}/" });
    $env->mock(_osname => sub { $params{osname} });

    return $env;
}
