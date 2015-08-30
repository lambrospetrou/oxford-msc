#!/bin/bash

# first, install the following tool:
# sudo apt-get install librsvg2-bin

gnuplot script_plot

rsvg-convert -f pdf -o housing-proper-withcompiler.pdf housing-proper-withcompiler.svg
