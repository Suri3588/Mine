#!/bin/bash
function update {
  file=$1
  deploymentName=$2
  deploymentNamespace=$3
  image=$4
  echo "Get latest deployed information"
  oldImage=`cat ${file}| yq "(.. | select(objects | has(\"image\"))).image"`
  echo "Update deploed image from ${oldImage} to ${image}"
  cat $file | yq -y "(.. | select(objects | has(\"image\"))).image=\"${image}\"" > $file.tmp
  cat $file.tmp > $file
  rm $file.tmp
}
echo "Updating services"
#update "${$1}/${$2}.yaml"
update "$1/$2.yaml" $2 $3 $4 $5
