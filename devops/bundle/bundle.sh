if [ "${SHARE}" ]; then
    ls -al
    echo ${SHARE}
    echo "Sync Share"
    mv litecoin.zip ${SHARE}/litecoin.zip
fi

echo "Finish Bundle"