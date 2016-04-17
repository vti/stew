use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);
use App::stew::rc;

subtest 'parse: parses rc file' => sub {
    my $rc = _build_rc();

    my ($fh, $filename) = tempfile;
    print $fh <<'EOF';
foo bar

[hello]

   there     world

#comment
    #indented comment
EOF
    seek $fh, 0, 0;

    is_deeply $rc->parse($filename), {
        '_' => {
            foo => 'bar'
        },
        hello => {
            there => 'world'
        }
    };
};

done_testing;

sub _build_rc {
    App::stew::rc->new;
}
