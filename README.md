# nom

**nom** is a command line tool that helps you lose weight by tracking your energy intake and creating a negative feedback loop. It's inspired by John Walker's [The Hacker's Diet](https://www.fourmilab.ch/hackdiet/) and tries to automate things as much as possible.

## Installation

You'll need Ruby, Rubygems and gnuplot. On Windows, make sure that gnuplot's binary directory is added to your `PATH` during installation.

Then run this command:

    $ gem install nom

When you run `nom` for the first time, it will ask for your current and your desired weight.

## Usage

Call `nom` without arguments to get a summary of your current status:

    $ nom
    5.3 kg down (34%), 10.3 kg to go!

    Today: (1774)

       (200) Griespudding
       (110) Graubrot
       (125) Käse
        (87) Orangensaft
    ---------------------
      (1252) remaining

You ate/drank something? Look up at FDDB how much energy it contained. (The search is German only for now, sorry.)

    $ nom Mate
    Club Mate (Brauerei Loscher)
        (40) 1 Glas (200 ml)
        (66) 1 kleine Flasche (330 ml)
        (100) 1 Flasche (500 ml)
    Mate Tee, Figurfit (Bad Heilbrunner)
        (0) 1 Beutel (2 ml)
        (1) 100 g (100 ml)
    Mate Tee, Orange (Bad Heilbrunner)
        (2) 1 Glas (200 ml)
        (0) 15 Filterbeutel (1 ml)
    Mate Tee, Guarana (Bad Heilbrunner)
        (0) 1 Glas (200 ml)
    Club-Mate Cola (Brauerei Loscher)
        (99) 1 Flasche (330 ml)
        (60) 1 Glas (200 ml)

Report your energy intake:

    $ nom Club-Mate 100

Enter your weight regularly:

    $ nom 78.2

And get nice graphs. The upper graph shows weight over time, with a weighted (no pun intended) moving average, a weight prediction, and a green finish line. The lower graph shows daily energy intake targets and actual intake:

    $ nom plot

![Graphs of weight and input over time](http://files.morr.cc/nom-0.1.0.svg)

Enter `nom help` if you're lost:

    Available subcommands:
          status                      Display a short food log
       w, weight <weight>             Report a weight measurement
       s, search <term>               Search for a food item in the web
       n, nom <description> <energy>  Report that you ate something
       y, yesterday <desc.> <energy>  Like nom, but for yesterday
       p, plot                        Plot a weight/intake graph
       l, log                         Display the full food log
       g, grep <term>                 Search in the food log
       e, edit                        Edit the input file
      ew, editw                       Edit the weight file
       c, config                      Edit the config file (see below for options)
          help                        Print this help
    There are some useful defaults:
          (no arguments)              status
          <number>                    weight <number>
          <term>                      search <term>
          <term> <number>             nom <term> <number>
    Configuration options (put these in /home/seb/.nom/config):
          rate                        How much weight you want to lose per week (default: '0.5')
          goal                        Your target weight
          image_viewer                Your preferred svg viewer, for example 'eog -f', 'firefox', 'chromium' (default: 'xdg-open')
          unit                        Your desired base unit in kcal (default: '1')
          start_date                  The first day that should be considered by nom [yyyy-mm-dd]
          balance_start               The day from which on nom should keep track of a energy balance [yyyy-mm-dd]

## Conventions

*nom* looks for its configuration directory in `~/.local/share/nom`, or `~/.nom/` (in that order),
and operates on three files in that configuration directory:
* `config` contains configuration settings
* `input` contains stuff you ate
* `weight` contains weight measurements.
The files are plain text, you can edit them by hand.

By default, energy quantities will have the unit "kcal". You can change this by adding a line like `unit: 0.239` to your `config`, which means you want to use the unit "0.239 kcal" (= "1 kJ"). Energy quantities are displayed in parentheses: `(42)`

Weight quantities are displayed as "kg", but you can use arbitrary units, like pounds.

## License: GPLv2+

*nom* is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
