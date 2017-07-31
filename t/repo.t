use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use File::Temp qw(tempdir);
use App::stew::repo;

subtest 'mirrors stew' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $build);

    my $to = "$build/stew/single_1.0.stew";

    is $repo->mirror_stew('single_1.0'), $to;

    ok -f $to;
};

subtest 'mirrors source' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $build);

    my $to ="$build/src/single-1.0.tar.gz";

    is $repo->mirror_src('single-1.0.tar.gz'), $to;

    ok -f $to;
};

subtest 'mirrors dist' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $build);

    my $to = "$build/dist/linux/x86_64/other_1.0_linux-x86_64.tar.gz";

    is $repo->mirror_dist('other', '1.0'), $to;

    ok -f $to;
};

subtest 'mirrors index from directory' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $build);

    my $to ="$build/index";

    is $repo->mirror_index, $to;

    ok -f $to;

    my $index = do { local $/; open my $fh, "$build/index"; <$fh> };
    like $index, qr{src/single-1.0.tar.gz};
    like $index, qr{stew/single_1.0.stew};
    like $index, qr{dist/linux/x86_64};
};

subtest 'mirrors index from http' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $ua = _mock_ua();

    my $repo = _build_repo(
        path        => 'http://sources.local',
        mirror_path => $build,
        ua          => $ua
    );

    my $to = "$build/index";

    is $repo->mirror_index, $to;

    ok -f $to;

    my $index = do { local $/; open my $fh, "$build/index"; <$fh> };
    like $index, qr{src/single-1.0.tar.gz};
    like $index, qr{stew/single_1.0.stew};
    like $index, qr{dist/linux/x86_64};
};

subtest 'correctly sorts packages' => sub {
    my $build = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $build);

    $repo->mirror_index;

    my $index = do { local $/; open my $fh, "$build/index"; <$fh> };
    my @stews = grep {/^stew\/single/} split /\n/, $index;

    is_deeply \@stews,
      [
        'stew/single_0.8.stew',
        'stew/single_0.9.stew',
        'stew/single_1.0.stew',
        'stew/single_1.0p1.stew',
      ];
};

subtest 'mirrors file' => sub {
    my $from = tempdir(CLEANUP => 1);
    my $to   = tempdir(CLEANUP => 1);

    open my $fh, '>', "$from/file";
    print $fh 'hihi';
    close $fh;

    my $repo = _build_repo(mirror_path => $to);

    $repo->mirror_file("$from/file", $to);

    ok -f "$to/file";
};

subtest 'mirrors http file' => sub {
    my $to   = tempdir(CLEANUP => 1);

    my $repo = _build_repo(mirror_path => $to, ua => _mock_ua());

    $repo->mirror_file('http://sources.local/file', $to);

    ok -f "$to/file";
};

subtest 'retries when http mirror fails' => sub {
    my $to   = tempdir(CLEANUP => 1);

    my $try = 0;

    my $repo = _build_repo(
        mirror_path => $to,
        ua          => _mock_ua(
            mirror => sub {
                shift;
                my ($url, $to) = @_;

                if ($try == 0) {
                    $try++;

                    return {
                        success => 0,
                        status  => '599',
                        reason  => 'Connection refused',
                        content => 'Error'
                    };
                }

                open my $fh, '>', $to or die $!;
                print $fh 'haha';
                close $fh;

                return {success => 1};
            }
        )
    );

    $repo->mirror_file('http://sources.local/file', $to);

    ok -f "$to/file";
};

done_testing;

sub _mock_ua {
    my (%params) = @_;

    my $pages = {
        'http://sources.local/stew' => {
            success => 1,
            content => <<'EOP'
<html>
<head><title>Index of /stew/</title></head>
<body bgcolor="white">
<h1>Index of /stew/</h1><hr><pre><a href="../">../</a>
<a href="single_1.0.stew">single_1.0</a>                                 15-Oct-2015 08:54                 10
</pre><hr></body>
</html>
EOP
        },
        'http://sources.local/src' => {
            success => 1,
            content => <<'EOP'
<html>
<head><title>Index of /src/</title></head>
<body bgcolor="white">
<h1>Index of /stew/</h1><hr><pre><a href="../">../</a>
<a href="single-1.0.tar.gz">single-1.0</a>                                 15-Oct-2015 08:54                 10
</pre><hr></body>
</html>
EOP
        },
        'http://sources.local/dist' => {
            success => 1,
            content => <<'EOP'
<html>
<head><title>Index of /dist/</title></head>
<body bgcolor="white">
<h1>Index of /stew/</h1><hr><pre><a href="../">../</a>
<a href="linux/">linux</a>                                 15-Oct-2015 08:54                 10
</pre><hr></body>
</html>
EOP
        },
        'http://sources.local/dist/linux' => {
            success => 1,
            content => <<'EOP'
<html>
<head><title>Index of /dist/linux/</title></head>
<body bgcolor="white">
<h1>Index of /stew/</h1><hr><pre><a href="../">../</a>
<a href="x86_64/">x86_64</a>                                 15-Oct-2015 08:54                 10
</pre><hr></body>
</html>
EOP
        },
        'http://sources.local/file' => {
            success => 1,
            content => 'hihi'
        }
    };

    my $ua = Test::MonkeyMock->new;
    $ua->mock(
        get => sub {
            shift;
            my ($url) = @_;

            return $pages->{$url} if exists $pages->{$url};

            die "unknown url '$url'";
        }
    );
    $ua->mock(
        mirror => $params{mirror} || sub {
            shift;
            my ($url, $to) = @_;

            if (defined(my $content = $pages->{$url})) {
                open my $fh, '>', $to or die $!;
                print $fh $content;
                close $fh;

                return {success => 1};
            }

            die "unknown url '$url'";
        }
    );

    return $ua;
}

sub _build_repo {
    my (%params) = @_;

    my $ua = $params{ua};

    return App::stew::repo->new(
        ua => $ua,
        os   => 'linux',
        arch => 'x86_64',
        path => 't/repo',
        %params
    );
}
