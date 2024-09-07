echo "Validating - $2"
packer validate $1/$2
echo "Building - $2"
packer build $1/$2