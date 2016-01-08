package App::stew::uninstaller;

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

    $self->{base} = $params{base};
    $self->{prefix} = $params{prefix} || 'local';

    return $self;
}

sub uninstall {
    my $self = shift;
    my (@packages) = @_;

    my $snapshot = App::stew::snapshot->new(base => $self->{base});
    $snapshot->load;

    foreach my $package (@packages) {
        if (!$snapshot->is_installed($package)) {
            warn "$package not installed. Skipping\n";
        }
        else {
            info sprintf "Uninstalling '%s'...", $package;
            my $info = $snapshot->get_package($package);

            foreach my $file (@{$info->{files}}) {
                _unlink "$self->{base}/$self->{prefix}/$file";
            }

            $snapshot->mark_uninstalled($package);
        }
    }
}

1;
