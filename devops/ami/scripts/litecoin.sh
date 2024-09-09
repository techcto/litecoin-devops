#!/bin/bash

args=("$@")

sync(){
    echo "Upload Blockchain to S3"
    cd /root/.litecoin/blocks
    tar -czvf blocks.tar.gz *
    aws s3 cp blocks.tar.gz s3://litecoin-pro/blocks.tar.gz
    rm -Rf blocks.tar.gz
}

restore(){
    cd /root/.litecoin/blocks
    aws s3 cp s3://litecoin-pro/blocks.tar.gz blocks.tar.gz
	tar -xzvf blocks.tar.gz
    rm -Rf blocks.tar.gz
}

$*