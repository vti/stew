package App::stew::cmdbuilder;

use strict;
use warnings;

use List::Util qw(max first);
use Pod::Usage qw(pod2usage);
use App::stew::cmd::install;
use App::stew::cmd::build;
use App::stew::cmd::list_installed;
use App::stew::cmd::uninstall;
use App::stew::cmd::autoremove;
use App::stew::cmd::exec;
use App::stew::cmd::help;

my @COMMANDS = (
    'install',    'uninstall', 'build', 'list-installed',
    'autoremove', 'exec',      'help',
);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub build {
    my $self = shift;
    my ($command) = @_;

    my $offset = max map { length } @COMMANDS;

    if (!$command || !first { $_ eq $command } @COMMANDS) {
        pod2usage();
    }

    return $self->_command_to_class($command)->new;
}

sub _command_to_class {
    my $self = shift;
    my ($command) = @_;

    $command =~ s/-/_/g;

    return 'App::stew::cmd::' . $command;
}

1;
