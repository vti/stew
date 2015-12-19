package App::stew::file;

use strict;
use warnings;

use App::stew::util qw(slurp_file error);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub parse {
    my $class = shift;
    my ($stew_file, $type) = @_;

    #_logn("Parsing '$stew_file'");

    my $content = slurp_file($stew_file);

    my $stew_class = $class->_sandbox($stew_file, $content, $type);
    return $stew_class->new;
}

sub _sandbox {
    my $self = shift;
    my ($file, $content, $type) = @_;

    $type = '' unless defined $type;

    my $class_name = 'stew::_build_' . _rand_str();

    my $package = <<"EOP";
    package $class_name;
    use strict;
    use warnings;
    my \$name;
    my \$version;
    my \$package;
    my \$file;
    my \@files;
    my \$url;
    my \@depends;
    my \@makedepends;
    my \@flags;

    sub new {
        my \$class = shift;

        my \$self = {};
        bless \$self, \$class;

        return \$self;
    }

    sub is_dependency     { '$type' eq 'depends' }
    sub is_makedependency { '$type' eq 'makedepends' }

    sub name        { \$name }
    sub version     { \$version }
    sub package     { \$package }
    sub file        { \$file }
    sub files       { \@files }
    sub url         { \$url }
    sub depends     { \@depends }
    sub makedepends { \@makedepends }
    sub flags       { \@flags }

    my \$phases = {};
    sub download(&) { \$phases->{download}    = shift }
    sub prepare(&)  { \$phases->{prepare}     = shift }
    sub build(&)    { \$phases->{build}       = shift }
    sub install(&)  { \$phases->{install}     = shift }
    sub cleanup(&)  { \$phases->{cleanup} = shift }

    sub phase { \$phases->{\$_[1]} }

    sub is {
        my \$self = shift;
        my (\$flag) = \@_;

        return !!grep { \$_ eq \$flag } \$self->flags;
    }

    sub run {
        my \$self = shift;
        my (\$phase) = \@_;

        if (\$phases->{\$phase}) {
            return \$phases->{\$phase}->()
        }

        return;
    }
    $content
    1;
EOP

    eval $package or error("Error compiling '$file': $@");

    return $class_name;
}

sub _rand_str {
    my @alpha = ('0' .. '9', 'a' .. 'z', 'A' .. 'Z');
    my $str = '';

    $str .= $alpha[rand($#alpha)] for 1 .. 16;

    return $str;
}

1;
