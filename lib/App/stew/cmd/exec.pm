package App::stew::cmd::exec;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use Cwd qw(cwd abs_path);
use File::Path qw(mkpath);
use File::Spec;
use App::stew::env;
use App::stew::util qw(info debug error);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_base;
    my $opt_prefix = 'local';
    GetOptionsFromArray(
        \@argv,
        "base=s"      => \$opt_base,
        "prefix=s"    => \$opt_prefix,
    ) or die "error";

    error("--base is required") unless $opt_base;

    $opt_base = abs_path($opt_base);

    $ENV{PREFIX} = File::Spec->catfile($opt_base, $opt_prefix);
    App::stew::env->setup;

    system(@argv);
}

1;
