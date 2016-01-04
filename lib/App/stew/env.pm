package App::stew::env;

use strict;
use warnings;

use Config;
use App::stew::util qw(debug slurp_file);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub setup {
    my $self = shift;

    _unshift_env(PATH => "$ENV{PREFIX}/bin");

    _unshift_env(LIBPATH         => "$ENV{PREFIX}/lib");
    _unshift_env(LIBRARY_PATH    => "$ENV{PREFIX}/lib");
    _unshift_env(LD_LIBRARY_PATH => "$ENV{PREFIX}/lib");

    _unshift_env(CPATH              => "$ENV{PREFIX}/include");
    _unshift_env(C_INCLUDE_PATH     => "$ENV{PREFIX}/include");
    _unshift_env(CPLUS_INCLUDE_PATH => "$ENV{PREFIX}/include");
}

sub detect_os {
    my $self = shift;

    my $os = $self->_osname;

    if ($os eq 'linux') {
        my $debian_version = $self->_root . 'etc/debian_version';
        my $suse_version   = $self->_root . 'etc/SuSE-release';
        my $redhat_version = $self->_root . 'etc/redhat-release';

        my $dist_name = 'generic';
        my $dist_ver  = '';

        if (-f $debian_version) {
            $dist_name = 'debian';

            my $content = slurp_file $debian_version;
            my ($ver) = $content =~ m/(\d+)/;
            $dist_ver = $ver if $ver;
        }
        elsif (-f $suse_version) {
            $dist_name = 'suse';

            my $content = slurp_file $suse_version;
            my ($ver) = $content =~ m/VERSION\s*=\s*(\d+)/;
            $dist_ver = $ver if $ver;
        }
        elsif (-f $redhat_version) {
            my $content = slurp_file $redhat_version;
            if ($content =~ m/centos/i) {
                $dist_name = 'centos';
            }
            elsif ($content =~ m/red\s*hat/i) {
                $dist_name = 'redhat';
            }

            my ($ver) = $content =~ m/release\s*(\d+)/;
            $dist_ver = $ver if $ver;
        }

        $os .= "-$dist_name";
        $os .= "-$dist_ver" if $dist_ver;
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
sub _root   { '/' }

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
