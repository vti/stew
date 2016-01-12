#!/bin/sh

cpanm --pp --installdeps . -L local
fatpack-simple script/stew
