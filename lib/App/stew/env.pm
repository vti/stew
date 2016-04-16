package App::stew::env;

use strict;
use warnings;

use Config;
use Linux::Distribution;
use App::stew::util qw(debug error slurp_file);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{prefix} = $params{prefix} || error 'prefix required';

    return $self;
}

sub setup {
    my $self = shift;

    my $prefix = $self->{prefix};

    _unshift_env(PATH => "$prefix/bin");

    _unshift_env(LIBPATH         => "$prefix/lib");
    _unshift_env(LIBRARY_PATH    => "$prefix/lib");
    _unshift_env(LD_LIBRARY_PATH => "$prefix/lib");

    _unshift_env(CPATH              => "$prefix/include");
    _unshift_env(C_INCLUDE_PATH     => "$prefix/include");
    _unshift_env(CPLUS_INCLUDE_PATH => "$prefix/include");
}

sub detect_os {
    my $self = shift;

    my $os = $self->_osname;

    if ($os eq 'linux') {
        my $dist_name = Linux::Distribution::distribution_name() // 'generic';
        my $dist_version = eval { Linux::Distribution::distribution_version() };

        if ($dist_version && $dist_version =~ m/^(\d+(?:\.\d+)?)/) {
            $dist_version = $1;
        }
        else {
            $dist_version = undef;
        }

        $os .= "-$dist_name";
        $os .= "-$dist_version" if $dist_version;
    }
    elsif ($os eq 'darwin') {
        my $cmd = 'sw_vers';

        my $output = $self->_run_cmd($cmd);

        my ($dist_version) = $output =~ m/ProductVersion:\s+(\d+\.\d+)/;

        $os .= "-osx";
        $os .= "-$dist_version" if $dist_version;
    }
    elsif ($os eq 'cygwin') {
        my $cmd = 'uname -r';

        my $output = $self->_run_cmd($cmd);

        my ($dist_version) = $output =~ m/^(\d+\.\d+)/;

        $os = "windows-$os";
        $os .= "-$dist_version" if $dist_version;
    }

    return $os;
}

sub detect_arch {
    my $self = shift;

    my $arch;

    chomp($arch //= `uname -m`);
    $arch = lc $arch;

    return $arch;
}

sub _osname { $^O }

sub _run_cmd {
    my $self = shift;
    my ($cmd) = @_;

    return `$cmd`;
}

sub _unshift_env {
    my ($var, $value) = @_;

    if ($ENV{$var}) {
        $ENV{$var} = "$value:$ENV{$var}";
    }
    else {
        $ENV{$var} = $value;
    }

    debug "Setting ENV{$var}=$ENV{$var}";
}

1;
