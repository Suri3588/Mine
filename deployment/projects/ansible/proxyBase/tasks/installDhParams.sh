#!/bin/bash
if [[ "$#" < "1" ]]; then
  privateDir=/nucleus/ssl/private/
else
  privateDir=$1
fi

openssl dhparam -out dhparams.pem 2048
sudo cp dhparams.pem $privateDir
rm dhparams.pem
