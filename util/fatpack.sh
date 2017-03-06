#!/bin/sh

export PERL5LIB=".:$PERL5LIB"

cpanm -n --pp --installdeps . -L local
cpanm -n --pp Getopt::Long Pod::Escapes Pod::Simple Pod::Find Pod::Usage HTTP::Tiny -L local

cpanm -n --pp App::FatPacker::Simple -L perl5
perl -Mlocal::lib=perl5 perl5/bin/fatpack-simple script/stew
