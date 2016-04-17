package App::stew::cmd::exec;

use strict;
use warnings;

use base 'App::stew::cmd::base';

use Getopt::Long qw(GetOptionsFromArray);
use Cwd qw(abs_path);
use File::Spec;
use App::stew::env;
use App::stew::util qw(info debug error);

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_base;
    my $opt_prefix = 'local';
    GetOptionsFromArray(
        \@argv,
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix,
    ) or die "error";

    error("--base is required") unless $opt_base;

    $opt_base = abs_path($opt_base);

    my $prefix = File::Spec->catfile($opt_base, $opt_prefix);

    App::stew::env->new(prefix => $prefix)->setup;

    system(@argv);
}

1;
