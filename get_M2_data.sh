#!/bin/bash

if [[ $# -eq 0 ]]; then
   $0 -h
   exit 1
fi

# Server version of curl is a bit old...
#curldir='/n/home13/seastham/curl'
curlbin=curl
#$curlbin --version

# Options for MERRA-2
CNYear=2015
CNMo=1
CNDay=1

month_bounds="1,12"
targ_yr=NONE
out_dir=MERRA2
get_cn=false
cn_only=false
use_wget=false
while getopts 'o:y:m:cxhbw:' OPTION; do
  case "$OPTION" in
    b)
      curlbin=$OPTARG
      ;;
    w)
      use_wget=true
      ;;
    y)
      targ_yr="$OPTARG"
      ;;
    m)
      month_bounds="$OPTARG"
      ;;
    c)
      get_cn=true
      ;;
    x)
      cn_only=true
      ;;
    o)
      out_dir="$OPTARG"
      ;;
    h|?)
      echo "Script usage: $(basename $0) [-y YYYY] [-m M1,M2] [-o dir]"
      echo "Downloads MERRA-2 data from Compute Canada"
      echo "Options (defaults given in square brackets if argument needed):"
      echo " -y YYYY          Download data for year YYYY [mandatory]"
      echo " -m M1,M2         Download only months M1 to M2 (inclusive) [1,12]"
      echo " -c               Also download constant (CN) data"
      echo " -o dir           Download to target directory [./MERRA2]"
      echo " -b /path/to/curl Use alternative curl binary at /path/to/curl [curl]"
      echo " -h               Show this help message"
      echo " -w               Use wget instead of curl"
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

if [[ "$get_cn" == "true" && "$cn_only" == "true" ]]; then
   echo "Options -c and -x cannot be passed together"
   exit 81
fi

# To get constant data regardless of year being downloaded, call this script with the -x option
if [[ "$get_cn" == "true" ]]; then
   if [[ "$use_wget" == "true" ]]; then
      ./$0 -x -o "$out_dir" -w
   else
      ./$0 -x -o "$out_dir" -b "$curlbin"
   fi
fi

if [[ "$cn_only" == "true" ]]; then
   targ_yr=$CNYear
   min_mo=$CNMo
   max_mo=$CNMo
else
   min_mo=100
   max_mo=0
   for targ_mo_str in $(echo $month_bounds | sed "s/,/ /g"); do
      targ_mo="$((10#$targ_mo_str))"
      echo $targ_mo
      if [[ ${targ_mo} -lt ${min_mo} ]]; then
         min_mo=$targ_mo
      fi
      if [[ ${targ_mo} -gt ${max_mo} ]]; then
         max_mo=$targ_mo
      fi
   done
fi

# Check that a year was actually passed
if [[ "$targ_yr" == "NONE" ]]; then
   echo "Year must be passed as -y YYYY"
   exit 90
fi

iYear=$targ_yr
loMo=$min_mo
hiMo=$max_mo

if [[ ! -d $out_dir ]]; then
   echo "$out_dir does not exist - attempting to create"
   mkdir $out_dir
   if [[ $? -ne 0 ]]; then
      echo "Could not create output directory $out_dir"
      exit 82
   fi
fi

cd $out_dir

baseDir="http://geoschemdata.computecanada.ca/ExtData"
baseDirCount=3
cutDirCount=$(( $baseDirCount + 2 ))

dCount=(31 28 31 30 31 30 31 31 30 31 30 31)

remYear=$(( $iYear - 1900 ))
if [[ $(( $remYear % 4 )) -eq 0 ]]; then
   isLeap=true
else
   isLeap=false
fi

if [[ "$cn_only" == "true" ]]; then
   echo "Downloading CN data (stored under $CNYear/$CNMo)"
else
   echo "Downloading all data for year $targ_yr, months $min_mo to $max_mo"
fi

if [[ ! -d $iYear ]]; then mkdir $iYear; fi
cd $iYear
for iMo in $( seq $loMo $hiMo )
do
    printf -v xMo "%02d" $iMo
    echo "Retrieving $iYear/$xMo..."
    if [[ ! -d $xMo ]]; then mkdir $xMo; fi
    cd $xMo
    nDays=${dCount[$(( $iMo - 1 ))]}
    if [ $isLeap == true ] && [ $iMo -eq 2 ]; then
       nDays=$(( $nDays + 1 ))
    fi
    if [[ "$cn_only" == "true" ]]; then
       nDays=1
    fi
    for iDay in $( seq 1 $nDays )
    do
       printf -v xDay "%02d" $iDay
       # Is this the month with the CN data?
       if [ $iYear -eq $CNYear ] && [ $iMo -eq $CNMo ] && [ $iDay -eq $CNDay ]; then
          # Download CN data first
          if [[ "$cn_only" == "true" ]]; then
             fList=( CN )
          else
             fList=( CN A3cld A3dyn A3mstC A3mstE A1 I3 )
          fi
       else
          fList=( A3cld A3dyn A3mstC A3mstE A1 I3 )
       fi
       for iFile in ${fList[@]}; do
          #echo "$iYear $iMo $iDay: $iFile"
          targFile="MERRA2.${iYear}${xMo}${xDay}.${iFile}.05x0625.nc4"
          targFileFull="$baseDir/GEOS_0.5x0.625/MERRA2/$iYear/$xMo/$targFile"
          #echo $targFileFull
          if [[ "$use_wget" == "true" ]]; then
             wget -nH -c -nd "$targFileFull"
          else
             $curlbin --retry 50 -L -C - -O "$targFileFull"
          fi
          #echo $?
       done
    done
    cd ..
done
exit 0
