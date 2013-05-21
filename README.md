Ralligator: Rally for Reptiles
==============================

Snappy little rally CLI workflow that is integrated with git.

Usage
-----

    rally [-s STORY] <command>


Interface
---------

:construction: **Under Construction** :construction:


***`workon`***

&nbsp;
&nbsp;
Mark which story you are working on, (creating and) setting tasks to 'In-Progress' and creates a new branch.

***`show`***

&nbsp;
&nbsp;
Displays the current user story details on the command line.

***`notes`***

&nbsp;
&nbsp;
Appends notes to the current user story.

***`launch`***

&nbsp;
&nbsp;
When all else fails, you can always launch the rally story in a web browser.

Installation
------------

Install dependancies:

    gem install rally_rest_api launchy html2md term-ansicolor trollop

Clone this repo and symlink rally.rb into your path:

    git clone git://github.com/krockode/ralligator.git
    ln -s $PWD/ralligator/rally.rb $HOME/bin/rally

Create a file called `.rallyconf.yml` in your home directory that contains
your rally URL as well as your username and password, e.g.:

    rally:
      url: https://trial.rallydev.com/
      username: example@example.com
      password: password
