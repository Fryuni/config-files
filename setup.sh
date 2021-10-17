shell=$(readlink -f /proc/$$/exe)

echo "Running on $shell"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script requires sudo"
	exec sudo "$shell" "$0" "$@"
fi

apt-get update
# apt upgrade -y

apt-get install -y curl git wget apt-transport-https python3 python3-pip jq

gcloud=$HOME/google-cloud-sdk/bin/gcloud

if [ ! -f $gcloud ]; then
	curl -Lls https://sdk.cloud.google.com | $shell -s -- --disable-prompts --install-dir=$HOME
fi


$gcloud --quiet components update
$gcloud --quiet components install alpha beta kubectl docker-credential-gcr minikube

$gcloud --quiet config configurations activate default

$gcloud auth list --format=json | jq -e '.[] | select(.account == "luiz@lferraz.com")' > /dev/null
if [ $? ]; then
	$gcloud --quiet config set account luiz@lferraz.com
else
	$gcloud auth login
fi

$gcloud config set project lferraz-portfolio

cd rcfiles
for cipher in *.cipher; do
	echo "Cipherfile \"$cipher\" being decrypted to \"~/.${cipher%.cipher}\""
	
	$gcloud kms decrypt --ciphertext-file "$cipher" --plaintext-file "$HOME/.${cipher%.cipher}" --location global --keyring cipher-files --key rcfiles
done

for rcfile in *rc; do
	echo "Linking rcfile $rcfile"
	
	ln -s $(readlink -f $rcfile) ~/.$rcfile
done

# NuShell
mkdir -p $HOME/.config/nu
ln -s $(readlink -f nushell.toml) $HOME/.config/nu/config.toml
cd ..

curl -Lls https://get.docker.com | sh -s || true

curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

curl -Lls https://get.volta.sh | sh -s || true

apt-get install -y pkg-config libssl-dev libxcb-composite0-dev libx11-dev gcc

rm -rf $HOME/build-source
mkdir -p $HOME/build-source
git clone --depth 1 --single-branch https://github.com/nushell/nushell.git $HOME/build-source/nushell
RUSTFLAGS="-C target-cpu=native" cargo install --path $HOME/build-source/nushell --features=extra


