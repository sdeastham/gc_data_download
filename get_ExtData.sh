#!/bin/bash

out_dir='.'
mkdir_opts=''
while getopts 'o:h' OPTION; do
  case "$OPTION" in
    o)
      out_dir="$OPTARG"
      ;;
    h|?)
      echo "script usage: $(basename $0) [-o /path/to/Extdata] PATH1 PATH2 PATH3 ..." >&2
      echo "All download paths should be relative to ExtData. It is almost always"
      echo "easiest to simply run this file from within the ExtData directory."
      echo "Options:"
      echo " -o /path/to/ExtData   Path to ExtData directory (optional)"
      echo "Example (downloads v2019 VOLCANO data and all POET emissions):"
      echo "./$(basename $0) HEMCO/VOLCANO/v2019-04 HEMCO/POET"
      if [[ "$OPTION" == "h" ]]; then
         exit 0
      else
         # Bad argument
         exit 1
      fi
      ;;
  esac
done
shift "$(($OPTIND -1))"

cd $out_dir

for iPath in "$@"
do
	echo "Retrieving $iPath..."
        # Old code - obsolete as of 2019-11-26
	#wget -r -nH -N --cut-dirs=4 "ftp://ftp.as.harvard.edu/gcgrid/geos-chem/data/ExtData/$iPath/*"
        # THIS WORKS! Need BOTH trailing slash and "--no-parent" to prevent it from ascending
        # Also need "-e robots=off" to prevent it from downloading robots.txt
	wget -r --no-parent -nH -N --cut-dirs=1 -e robots=off -R "*.html,*.gif,index.html*" "http://geoschemdata.computecanada.ca/ExtData/$iPath/"
done
