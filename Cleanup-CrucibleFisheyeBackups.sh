#! /bin/bash

## This script cleans up the folder at $path, deleting old files until it is equal to or smaller than $size in Megabytes
## Created to cleanup atlassian backups, but can do other things
## Created by Adam Warner

# Size to shrink folder to in MB
targetSize=10240

# Path to target
path='/usr/lib/atlassian/backup'

# Gets the current size in MB, don't change this
size=$(du -ms "$path" | awk '{print $1}')

# loops by deleting oldest file until target is reached
while [ $size -ge $targetSize ] 
do 
    # leave the %T for sorting, though it seems extraneous, it's good for other items if we reuse this
    oldestFile=$(find $path -type f -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}')
    rm "$oldestFile"
    size=$(du -ms "$path" | awk '{print $1}')
done