package App::stew::cmd::uninstall;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use App::stew::uninstaller;

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
    my $opt_verbose;
    GetOptionsFromArray(
        \@argv,
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix,
        "verbose"  => \$opt_verbose,
    ) or die "error";

    error("--base is required") unless $opt_base;

    my $uninstaller =
      App::stew::uninstaller->new(base => $opt_base, prefix => $opt_prefix);

    $uninstaller->uninstall(@argv);
}

1;
