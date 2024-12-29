# GPG Cheat Sheet

Exported from: https://gock.net/blog/2020/gpg-cheat-sheet
Author: Andy Gock

## List keys

List public keys

    gpg --list-keys

List all secret keys

    gpg --list-secret-keys

List public or secret keys, but show subkey fingerprints as well

    gpg --list-keys --with-subkey-fingerprints
    gpg --list-secret-keys --with-subkey-fingerprints

The key ring location is normally shown on the first line on stdout.

## Use different key ring

List keys but use a different home directory for one command only

    gpg --homedir ~/.gnupg-alternate --list-keys

Set different home directory for session

    export GNUPGHOME=/mnt/c/Users/USER/AppData/Roaming/gnupg/
    gpg --list-keys

## Generate keys

Generate key pair

    gpg --full-generate-key

## Exporting keys

Export single public key or secret key, useful for backing up keys

    gpg -a --export KEYID > public.asc
    gpg -a --export-secret-key KEYID > secret.asc

Export all keys

    gpg -a --export > public-all.asc
    gpg -a --export-secret-key > secret-all.asc

Exported secret keys are protected with current secret key passphrase.

## Importing keys

List contents of key file without importing it

    gpg keys.asc

Verbose option to see fingerprint or both fingerprint/signatures too

    gpg --with-subkey-fingerprint keys.asc
    gpg -v keys.asc

Import keys, merging into current key ring

    gpg --import keys.asc

## Signing a key

View the fingerprint of a key, after confirming the key is authentic, sign the key.

    gpg --fingerprint KEYID
    gpg --sign-key KEYID

Or via the key editor

    gpg --edit-key KEYID
    gpg>fpr
    gpg>sign
    gpg>save

Optionally, export the key again and return to user

    gpg -a --export KEYID > signed-key.asc

Signing a key will automatically set the key's trust level to _full_.

If you local sign a key, the exported key to others doesn't contain the signatures, the signature is only valid to you.

    gpg --lsign-key KEYID

## Removing a key signature

Removing a local key signature

    gpg --edit-key KEYID
    gpg>delsig
    gpg>save

Revoking a published key signature. You can not delete a key signature.

    gpg --edit-key KEYID
    gpg>revsig
    gpg>save

If needed, upload the key and revocation certificate to key servers

    gpg --send-key KEYID

Or export the key with the revoked signature

    gpg -a --export KEYID > exported-key.asc

## Adding or removing a UID

    gpg --edit-key KEYID
    gpg>adduid
    (enter details as prompted)
    gpg>list
    gpg>save
    gpg>quit

## Changing primary UID

If you have multiple UIDs, this will change which UID is the primary one.

    gpg --edit-key KEYID
    gpg>list
    gpg>uid X
    gpg>primary
    gpg>save
    gpg>quit

## Edit key trust

    gpg --edit-key KEYID
    gpg>trust
    gpg>(enter trust level)
    gpg>save

The trust level you enter is based on:

    1 = I don't know or won't say
    2 = I do NOT trust
    3 = I trust marginally
    4 = I trust fully
    5 = I trust ultimately
    m = back to the main menu

Use _ultimate_ only for keys you've generated yourself. Signing a key will automatically set the key's trust level to _full_.

## Generate a revocation certificate

    gpg -a --gen-revoke KEYID > revoke.asc

## Renew an expired (sub)key

To change the expiry of a key

    gpg --edit-key KEYID
    gpg>expire
    gpg>key 1
    gpg>expire
    gpg>list
    gpg>save

If you have more subkeys, you can edit those with `key 2`, `key 3` etc. Use `list` to view the key details including expiry date. The default key edited is the primary key when no `key N` is specified, this is the first key shown in the `list` output, and can also be manually selected by `key 0`.

Then export the new key for distribution, and generate a new revocation certificate for safekeeping. The secret key doesn't change.

    gpg -a --export KEYID > public.asc
    gpg -a --gen-revoke KEYID > revoke.asc

## Encryption

Encrypt file to one recipient key. This will write to a default filename, in this case `file.txt.gpg`

    gpg -e -r KEYID file.txt

Sign and encrypt a file

    gpg -s -e -r KEYID file.txt

Encrypt to multiple recipients

    gpg -e -r KEY1 -r KEY2 -r KEY3 file.txt

Encrypt and specify output file

    gpg -e -r KEYID -o OUTPUT INPUT

Encryption uses compression by default. To disable, use the option `-z 0`. This will speed up the process if encrypting a large file which is already compressed.

    gpg -e -z 0 -r KEYID file.tar.gz

Encrypt contents from standard input

    cat "my secret message" | gpg -e -r KEYID > message.txt.gpg
    tar -jc /var/log/secret | gpg -z 0 -e -r KEYID > secret.tar.bz2.gpg

Symmetrically encrypt a file using a passphrase

    gpg -c file.txt

## Create or verify signature

Sign file without encrypting, using a detached signature. This will write to a default file `file.txt.asc` in the example below.

    gpg -a -s file.txt

But with clear signed attached signature

    gpg --clear-sign file.txt

Sign using a non default secret key. Useful if you have multiple secret keys on your key ring.

    gpg --default-key KEYID -a -s file.txt

Verify a clearsigned or dettached signature

    gpg --verify file.txt.asc

## Decryption

List recipients of a encrypted file

    gpg --list-only FILE

Decrypt a file to user defined output filename

    gpg -d -o OUTPUT FILE

Decrypt a file using default file name, e.g `file.txt.gpg` decrypts to `file.txt`

    gpg -d FILE

## Batch encrypt and decrypt

Encrypt all `*.jpg` files in the current directory to two recipients, with no compression

    find . -maxdepth 1 -type f -name "*.jpg" -exec gpg -z 0 -e -r KEY1 -r KEY2 -o {}.gpg {} \;

Decrypt all `*.gpg` files in current directory. If `--output` is not used, it will write `file.txt.gpg` to `file.txt`

    gpg --decrypt-files *.gpg

Do the same using a shell script

    #!/bin/bash
    read -rsp "Enter passphrase: " PASSPHRASE
    for FILE in *.*.gpg; do
        echo "Extracting $FILE to ${FILE%.gpg}."
        echo "$PASSPHRASE" | gpg --passphrase-fd 0 --batch -d --output "${FILE%.gpg}" "$FILE"
    done

Decrypt using passphrase from standard input

    echo "passphrase" | gpg --passphrase-fd 0 --batch -d -o file.txt file.txt.gpg

## Using a keyserver

`KEYID` is the last 4 bytes (8 hexadecimal chars) of your fingerprint, e.g `D9B2766F`

Sending or uploading a key to a key server

    gpg --keyserver SERVER --send-key KEYID

Receiving a key from a key server

    gpg --keyserver SERVER --recv-key KEYID

If you don't use the `--keyserver SERVER` option, the default server will be used. See what your default server is.

    gpgconf --list-options gpg

Common and popular keyservers are

    pgp.mit.edu
    pool.sks-keyservers.net

Search for keys

    gpg --keyserver SERVER --search-keys STRING
