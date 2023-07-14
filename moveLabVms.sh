#!/bin/bash
labVms=("5010" "5011" "5013")
controllers=("sata" "scsi")
target="ceph_ec_hdd"
declare -a gd

# Get 'pairing' of VMID, Disk, and Location
counter=0
for v in $labVms
do
gd+="v_$v"
declare -n varName="v_$v"
declare -A "$varName"
    for c in $controllers
    do  
        qmOut=($( qm config $v | grep -e "^$c" | cut -d ':' -f 1,2 | tr -d ":" | awk '{ gsub(" ", ";"); print }' ))
        if [ -z $qmOut ]; then
            echo "no $c type controllers on VMID $v"
            break
        fi

        for l in $qmOut
        do
            ${!varName}+=["$(echo $l | cut -d ";" -f 1 | awk '{ gsub("", ";"); print}')"]="$(echo $l | cut -d ";" -f 2)"]
        done
    done
done


    


<<comment
for v in $labVms
do
    for c in $controllers
    do
        echo "Moving vmid $v's disk $c to $target"
        qm move-disk $v $c $target --delete 1
    done
done
comment