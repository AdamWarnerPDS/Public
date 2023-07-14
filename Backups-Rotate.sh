#!/bin/bash

# Variables
keepLast=3
keepDays=30
keepWeeks=4
keepMonths=12
keepYears=2
weekMarker="Sunday"

bucket="AndroidPersonal"

# Datetime extract regex 
# [[:digit:]]{4}((?:-[[:digit:]]{2})+)
# Faster to trim filenames?
# sed don't like non capturing groups ($:stuff)
# Lets do indexs instead
# cut -c 8-26 <<< "$sample"

# Date calculation 
# (date -d "3 weeks ago" +%Y-%m-%d)

# More transformation
# (date -d "3 weeks ago" +%Y-%m-%d)

# Get Day of week
# date +%A #full day | date =$a #abbr day | date +%u #int day mon=1 sun=7

<<comment
Example output from b2 ls

signal-2023-05-17-02-00-02.backup
signal-2023-05-21-03-25-00.backup
signal-2023-06-01-02-00-00.backup
signal-2023-06-04-02-00-00.backup
signal-2023-06-11-02-00-00.backup
signal-2023-06-12-02-00-00.backup
signal-2023-06-13-02-00-01.backup
signal-2023-06-14-02-39-56.backup
signal-2023-06-15-02-00-00.backup
signal-2023-06-16-02-00-00.backup
signal-2023-06-17-02-00-01.backup
signal-2023-06-18-02-00-00.backup
signal-2023-06-19-02-00-00.backup
signal-2023-06-21-02-00-00.backup
signal-2023-06-22-02-00-00.backup
signal-2023-06-23-03-13-57.backup
signal-2023-06-24-02-00-00.backup
signal-2023-06-25-02-00-00.backup
signal-2023-06-26-02-00-01.backup
signal-2023-06-27-02-00-00.backup
signal-2023-06-28-02-00-00.backup
signal-2023-06-29-02-00-00.backup
signal-2023-06-30-02-00-01.backup 
comment

# send b2 ls to array
# stuff=$(b2 ls --recursive --withWildcard AndroidPersonal "*")

$backups=$(b2 ls --recursive --withWildcard $bucket "*")

# Functions Def
# assume $b for current backup filename
# assume $fDate for current extracted date from filename

check_year () {
    if $(date +%Y)
}

for b in ${backups[@]} do
    fDateTime=$( cut -c 8-26 <<< "$b" )
    fYear=$( cut -c 1-4 <<< "$fDateTime" )
    fMonth=$( cut -c 6-7 <<< "$fDateTime" )
    fDay=$( cut -c 9-10 <<< "$fDateTime" )
    fHour=$( cut -c 12-13 <<< "$fDateTime" )
    fMin=$( cut -c 15-16 <<< "$fDateTime" )
    fSec=$( cut -c 18-20 <<< "$fDateTime" )

done
