package App::stew::cmd::uninstall;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use App::stew::snapshot;
use App::stew::util qw(info debug error _unlink);

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
        "prefix=s"   => \$opt_prefix,
        "verbose"  => \$opt_verbose,
    ) or die "error";

    error("--base is required") unless $opt_base;

    my (@packages) = @argv;

    my $snapshot = App::stew::snapshot->new(base => $opt_base);
    $snapshot->load;

    foreach my $package (@packages) {
        if (!$snapshot->is_installed($package)) {
            warn "$package not installed. Skipping";
        }
        else {
            debug sprintf "Uninstalling '%s'...", $package;
            my $info = $snapshot->get_package($package);

            foreach my $file (@{$info->{files}}) {
                _unlink "$opt_base/$opt_prefix/$file";
            }

            $snapshot->mark_uninstalled($package);
        }
    }
}

1;
