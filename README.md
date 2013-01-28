ralligator
=========

Snappy rally CLI workflow that is integrated with git.

Installation
------------

Install dependancies:

    gem install rally_rest_api launchy html2md term-ansicolor

clone this repo and symlink rally.rb into your path:

    git clone git://github.com/krockode/ralligator.git
    ln -s $PWD/ralligator/rally.rb $HOME/bin/rally

Create a file called `.rallyconf.yml` in your home directory that contains
your rally URL as well as your username and password, e.g.:

    rally:
      url: https://trial.rallydev.com/
      username: example@example.com
      password: password

Usage
-----

    rally [options]

If operating within a git repository the ralligator will attempt to find a
rally ID in the current git branch name.

Running the command `rally` with no options will print the story details.
Type `rally --help` for further information.
