package App::stew::cmd::uninstall;

use strict;
use warnings;

use base 'App::stew::cmd::base';

use Getopt::Long qw(GetOptionsFromArray);
use App::stew::snapshot;
use App::stew::uninstaller;
use App::stew::util qw(error info);

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_base;
    my $opt_prefix = 'local';
    my $opt_force;
    GetOptionsFromArray(
        \@argv,
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix,
        "force"    => \$opt_force,
    ) or die "error";

    error("--base is required") unless $opt_base;

    my $snapshot = App::stew::snapshot->new(base => $opt_base, prefix => $opt_prefix);
    $snapshot->load;

    my $uninstaller =
      App::stew::uninstaller->new(base => $opt_base, prefix => $opt_prefix);

    if (!$opt_force) {
        foreach my $package (@argv) {
            next unless $snapshot->is_dependency($package);

            error "Cannot remove '$package' since it is was installed "
              . "as dependency and can break other packages"
              if $snapshot->is_required($package);
        }
    }

    $uninstaller->uninstall(@argv);

    info 'Done'
}

1;
