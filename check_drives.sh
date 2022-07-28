#!/bin/zsh
drives=(a b c d e f g)
finalOut=("dev Vendor SKU DefectList Uncor-Reads PowerOnMin \n")
for d in $drives;
do
    dr=""
    vend=""
    sku=""
    egdl=""
    ucr=""
    pot=""

    dr="/dev/sd${d}"
    out=$(smartctl $dr -x)

    vend=$(echo "$out" | grep -m 1 -e "Vendor:*" | awk '{print $2}'| awk '{ gsub(/ /,""); print }')
    sku=$(echo "$out" | grep -e "Product:*" | awk '{print $2,$3,$4}' | awk '{ gsub(/ /,""); print }')
    egdl=$(echo "$out" | grep -e "Elements in grown defect list*" | awk '{print $6}')
    ucr=$(echo "$out" | grep -A 7 -e "Error counter log:" | grep -e "^read:*" | awk '{print $8}')
    pot=$(echo "$out" | grep -e "Accumulated power on time*" | awk '{print $7}' | cut -c2-)

    finalOut=(${finalOut[@]}"$dr $vend $sku $egdl $ucr $pot \n")
done
echo $finalOut | column -t -s " "