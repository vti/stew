# NAME

App::stew - stew your dependencies!

# SYNOPSIS

    # Create the repository
    $ tree ../repo-stew
    dist/
        linux-debian-8/
            x86_64/
        linux-centos-7/
        linux-suse-11/
    stew/
    src/

    # Create stewfile with dependencies
    $ cat stewfile
    perl
    libgd
    libgd-perl

    # Bootstrap dependencies (build from source, or install from binaries)
    $ stew install --repo repo-stew .

    # Run your perl with your libraries in your own environment
    $ stew exec perl -MGD -e ''

# DESCRIPTION

`stew` is an in-app package manager.

`stew` allows you to package not only CPAN dependencies, but actually your perl and/or any other system libraries. All the
dependencies are installed into your project directory C<local/> by default. Shipping it to a deployment server is a no
brainer.

`stew` infrustucture consists of `stew repository` with `stewfile`s, sources and binary packages and app's local
installation of stew packages.

`stew repository` is just a simple directory structure (can be served as a static directory through a web server) with
`stew/`, `src/` and `dist/` directories.

- `stew/` has stewfiles (like `perl_5.22.stew`)
- `src/` original dependency sources (like `perl-5.22.tar.gz`)
- `dist/` binary packages (like `perl_linux-debian-9_x86_64_5.22.tar.gz`)

`stewfile`s are files with instructions on how to build the package (like ports in FreeBSD, Gentoo ebuild, ArchLinux PKGBUILDs
etc), they look like this:

    ---
    name: perl
    version: 5.22.1
    package: ${name}-${version}
    sources:
        - ${package}.tar.gz
    depends:
        - patch
        - less
    prepare:
        - tar xzf '${package}.tar.gz'
        - cd ${package}
    build:
        - cd '${package}'
        - >
            ./Configure
            -Duselargefiles
            -Duse64bitint
            -Dprefix=${PREFIX}
            -Dman1dir=none
            -Dman3dir=none
            -Uuseshrplib -Duserelocatableinc
            -Dvendorprefix=.../..
            -Accflags=-DPERLIO_BUFSIZ=32768
            -Uafs
            -Ud_csh
            -Ud_ualarm
            -Uusesfio
            -Uusenm
            -Ui_libutil
            -des
        - make
    install:
        - cd '${package}'
        - make install

`stew exec` then sets the correct `PATH`, `LD_LIBRARY_PATH` and other needed environment variables and runs the command.

## Building from source & Installing from binaries

The first time you compile all your dependencies from sources, the binaries packages are stored in `build/.cache/dist`
path and can be uploaded to the existing stew repository for later use. The next time the bootstrap is going to be done
from the binaries packages and won't take a lot of time.

## Commands

   install         install package
   uninstall       uninstall package
   build           build package without installing
   autoremove      remove not required dependencies
   list-installed  list installed packages
   exec            execute command in local environment
   help            detailed command help

## Version control

All the dependencies are versioned. It is possible for different versions to coexist in the same repository and only
install the ones needed.

## Stacks

Sometimes (actually very often) you want to have several repositories for
different versions of your app. Since there is nothing special in stew
repositories one can just create different subfolders for different
subrepositories:

    stew-repo/
        stacks/
            1.0/
                stew/
                src/
                dist/
            1.2/
                stew/
                src/
                dist/

And then just pass correct repository path when installing dependencies:

    stew install --repo stew-repo/stacks/1.0 .

## CPAN distributions

Since building your own CPAN stewfiles with all the dependencies from scratch can be daunting there is a special script
`cpan2stew` that does that for you:

    # Generate stewfiles saving sources to stew repository
    cpan2stew --local Plack

    # Generate stewfiles from the local CPAN mirror
    cpan2stew --cpan http://darkpan Plack

    # Generate stewfiles extracting dependencies from cpanfile
    cpan2stew --cpanfile cpanfile

## Relocatability

If you want to be able to move your application around, the dependencies have to be built as relocatable. Most of the
libraries don't create any problems, but some of them hardcode the paths during the compilation.

The perl's stewfile example from above is built as relocatable, so you can move your perl application without a problem.

# AUTHOR

Viacheslav Tykhanovskyi, `vti@cpan.org`.

# COPYRIGHT

Copyright (C) 2015-2017, Viacheslav Tykhanovskyi.

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl 5.10.
