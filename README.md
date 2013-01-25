rallycri (Rally Clear Reponsive Interface)
=========

A rally CLI workflow that integrates with git.

Installation
------------

Install dependancies:

    gem install rally_rest_api launchy html2md term-ansicolor

clone this repo and symlink rally.rb into your path:

    git clone git://github.com/krockode/rally-cli.git
    ln -s $PWD/rally-cli/rally.rb $HOME/bin/rally

Create a file called `.rallyconf.yml` in your home directory that contains
your rally URL as well as your username and password, e.g.:

    rally:
      url: https://trial.rallydev.com/
      username: example@example.com
      password: password

Usage
-----

    rally -[options] [rally id]

If operating within a git repository rallycri will attempt to find a rally ID
in the current git branch name.

Running the command `rally` with no options will print the story details.
Type `rally --help` for further information.
