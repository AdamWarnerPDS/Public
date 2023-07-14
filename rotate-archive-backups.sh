#!/bin/bash
uploadPath='/sftproot/adamsignal/upload/'
archivePath='/sftproot/adamsignal/upload/archivePath'
currentDate=$(date)
currentTime=$(date +%H-%M-%S%z)
lastMonth=$(if [ $currentMonth -eq 01 ])
firstOfMonthFile=

if [ "$(date +%m)" -eq "01" ]
then
    targetMonth="$(($(date +%Y)-1))-12"
else
    $targetMonth="$(date +%Y-$m)"
fi

targetMonthsFiles=$(find $uploadPath -name "