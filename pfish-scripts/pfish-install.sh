#!/bin/sh
mkdir -p $HOME/bin
wget --directory-prefix=$HOME/bin https://raw.githubusercontent.com/aquariumbio/protocols-to-edit/main/pfish-scripts/pfish-wrapper
install -m 0755 $HOME/bin/pfish-wrapper $HOME/bin/pfish
rm -f ~/bin/pfish-wrapper

