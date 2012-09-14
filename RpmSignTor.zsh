#!/bin/zsh

setopt extendedglob


#if [ -z "$1" ]; then
#    echo "arg1 - dir with rpms"
#    exit 1
#fi


RSA=0x5AC001F1
DSA=0xB4D403EA

echo "New rpms:"
for I in tor-*.rpm~tor-*.rh5_[0-9].*.rpm; do
    echo " - $I"
done
echo ""

echo "Old rpms:"
for I in tor-*.rh5_[0-9].*.rpm; do
    echo " - $I"
done
echo ""

echo "Using new RSA key $RSA"
rpm --resign --define "_gpg_name  $RSA" tor-*.rpm~tor-*.rh5_[0-9].*.rpm

echo "Using old DSA key $DSA"
rpm --resign --define "_gpg_name  $DSA" --define '__gpg_sign_cmd   %{__gpg}  gpg --batch --force-v3-sigs --digest-algo=sha1 --no-verbose --no-armor  --passphrase-fd 3 --no-secmem-warning  -u "%{_gpg_name}" -sbo %{__signature_filename} %{__plaintext_filename}' tor-*.rh5_[0-9].*.rpm



