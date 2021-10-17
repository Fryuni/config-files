running_shlike=$(readlink -f /proc/$$/exe)

echo "Running on $running_shlike"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script requires sudo"
	exec sudo "$running_shlike" "$0" "$@"
fi

apt-get update
# apt upgrade -y

apt-get install -y curl git wget apt-transport-https python3 python3-pip jq

curl -Lls https://sdk.cloud.google.com | $running_shlike -s -- --disable-prompts --install-dir=$HOME

gcloud=$HOME/google-cloud-sdk/bin/gcloud

$gcloud --quiet components install alpha beta kubectl docker-credential-gcr minikube

$gcloud --quiet config configurations activate default

if [ gcloud auth list --format=json | jq -e '.[] | select(.account == "luiz@lferraz.com")' > /dev/null -eq 0 ]; then
	$gcloud --quiet config set account luiz@lferraz.com
elif
	$gcloud auth login
fi
$gcloud 

