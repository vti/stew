package App::stew::cmd::autoremove;

use strict;
use warnings;

use base 'App::stew::cmd::base';

use Getopt::Long qw(GetOptionsFromArray);
use App::stew::snapshot;
use App::stew::uninstaller;
use App::stew::util qw(info);

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_prefix = 'local';
    my $opt_base;
    my $opt_dry_run;
    GetOptionsFromArray(
        \@argv,
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix,
        "dry-run"  => \$opt_dry_run,
    ) or die "error";

    error("--base is required") unless $opt_base;

    my $snapshot = App::stew::snapshot->new(base => $opt_base, prefix => $opt_prefix);
    $snapshot->load;

    my $uninstaller =
      App::stew::uninstaller->new(base => $opt_base, prefix => $opt_prefix);

    my @not_required = $snapshot->list_not_required;

    if ($opt_dry_run) {
        info sprintf "Will remove '%s'", join(', ', @not_required);
    }
    else {
        $uninstaller->uninstall(@not_required);
    }

    info "Done";
}

1;
