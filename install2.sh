#/bin/bash
# install2.sh
#    non-priviledged (scot4 user) install steps
#
# get variables from call
#
WHOAMI=$(whoami)
echo "Now running as $WHOAMI"


cd /home/scot4
source .bashrc
cd scot4
PWD=$(pwd)
echo "IN directory $PWD"

export KUBECONFIG=/home/scot4/.kube/config

VARIANT="prod"
REPOPATH="scot/scot4"
REPLICAS=2
SURGE=1
KUBECTL=/usr/local/bin/kubectl
HELM=/usr/local/bin/helm

while getopts "a:b:c:d:e:k:n:m:p:r:s:t:v:" options; do
    case "${options}" in
        a)
            AIRFLOW=${OPTARG}
            ;;
        b)
            REPLICAS=${OPTARG}
            ;;
        c) 
            TLS_CRT_FILE=${OPTARG}
            ;;
        d)
            SQLALCHEMY_DATABASE_URI=${OPTARG}
            ;;
        e)
            SURGE=${OPTARG}
            ;;
        k)
            TLS_KEY_FILE=${OPTARG}
            ;;
        n)
            REG_SECRET_NAME=${OPTARG}
            ;;
        m)
            S3SERVER=${OPTARG}
            ;;
        p)
            REPOPATH=${OPTARG}
            ;;
        r)
            REPOSERVER=${OPTARG}
            ;;
        s)
            SERVERNAME=${OPTARG}
            ;;
        t)
            REG_SECRET=${OPTARG}
            ;;
        v)
            VARIANT=${OPTARG}
            ;;
        *)
            echo "Invalid Option"
            exit 1
            ;;
    esac
done

echo "with vars:"
echo "REPOSERVER                = $REPOSERVER"
echo "REPOPATH                  = $REPOPATH"
echo "VARIANT                   = $VARIANT"
echo "SERVERNAME                = $SERVERNAME"
echo "AIRFLOW                   = $AIRFLOW"
echo "S3SERVER                  = $S3SERVER"
echo "SQLALCHEMY_DATABASE_URI   = $SQLALCHEMY_DATABASE_URI"
echo "TLS_KEY_FILE              = $TLS_KEY_FILE"
echo "TLS_CRT_FILE              = $TLS_CRT_FILE"
echo "KUBECONFIG                = $KUBECONFIG"
echo "REG_SECRET_NAME           = $REG_SECRET_NAME"
echo "REG_SECRET                = $REG_SECRET"
echo "REPLICAS                  = $REPLICAS"
echo "SURGE                     = $SURGE"

## this part of the install_helper.sh script intented to run as scot4 user

echo "Checking PyYAML status..."
PYYAMLVER=$(python3 -m pip freeze | grep -i pyyaml | awk -F== '{print $2}')
PYYAMLMAJ=$(echo $PYYAMLVER | awk -F. '{print $1}')

echo "pyYaml version = $PYYAMLVER"
echo "pyYaml major   = $PYYAMLMAJ"

if [ "$PYYAMLMAJ" == "" ] || [ "$PYYAMLMAJ" -lt 5 ]; then
    echo "Upgrading PyYAML..."
    python3 -m pip install --upgrade PyYAML
fi

# Create scot4 namespace as the scot4 user
if ! $KUBECTL get ns scot4; then
    echo "Creating scot4 namespace in kubernetes"
    $KUBECTL create ns scot4
fi

if ! $KUBECTL -n scot4 get secret scot4-tls 2>&1 >/dev/null; then
    # then add using kubectl
    echo "Creating scot4-tls"
    $KUBECTL create secret tls scot4-tls \
        --key="$TLS_KEY_FILE" \
        --cert="$TLS_CRT_FILE" \
        --namespace scot4
fi

if ! $KUBECTL -n scot4 get secret scot4-env-secrets 2>&1 >/dev/null; then
    # run autogen secrets
    echo "Generating Secrets"
    AGSOPTS=""
    if [ "$SQLALCHEMY_DATABASE_URI" != "x" ]; then
        AGSOPTS="$SQLALCHEMY_DATABASE_URI"
    fi
    python3 ./auto_gen_secrets.py $AGSOPTS

    # Load them
    echo "Applying Secrets"
    $KUBECTL -n scot4 apply -f scot4/auto_gen_secrets.yaml
    $KUBECTL -n scot4 apply -f scot4/auto_gen_flair_secrets.yaml
fi

# add pull secret if needed

if [ "$REG_SECRET" != "x" ] \
   && [ "$REG_SECRET_NAME" != "x" ] \
   && [ "$REPOSERVER" != "x" ]; then
    echo "merging pull secret for $REPOSERVER..."
    $KUBECTL create secret docker-registry \
        scot4-image-pull-secret \
        --docker-server=$REPOSERVER \
        --docker-username=$REG_SECRET_NAME \
        --docker-password $REG_SECRET \
        --namespace scot4
fi


# update values.yaml with appripriate stuff domain fdqn repos etc
echo "Updating values.yaml"
PWD=$(pwd)
# echo "IN directory $PWD"
YORIG="/home/scot4/scot4/OS_val_template"
YFILE="/home/scot4/scot4/OS_values.yaml"
cp -f $YORIG $YFILE
sed -ie "s|REPOSITORY|$REPOSERVER|g" $YFILE
sed -ie "s|REPOPATH|$REPOPATH|g" $YFILE
sed -ie "s/SERVERNAME/$SERVERNAME/g" $YFILE
sed -ie "s:AIRFLOW:$AIRFLOW:g" $YFILE
sed -ie "s:S3_SERVER:$S3SERVER:g" $YFILE
sed -ie "s|REPLICAS|$REPLICAS|g" $YFILE
sed -ie "s|SURGE|$SURGE|g" $YFILE

if [ "$SQLALCHEMY_DATABASE_URI" != "x" ];then
    sed -ie '/internalDB/ s/true/false/' $YFILE
fi

if [ "$REPOSERVER" != "x" ]; then
    sed -ie "s|# repository:|repository:|" $YFILE
    sed -ie "s|# flair:|flair:|" $YFILE
fi

# run helm command

echo "!!!"
echo "!!! WARNING: The next step WILL cause data loss.  "
echo "!!!          Your SCOT4 database will be wiped"
echo "!!!          and re-initialized. " 
echo "!!!          "
echo "!!!  This is what you want if you are installing for the first time."
echo "!!!  However, you do not want to do this to redeploy."
echo "!!!"
echo "!!!          <Ctrl-C> or enter 'no' at the prompt to abort"
echo "!!!          Enter 'yes' to proceed."
echo "!!!"

read -p "Enter yes to proceed with initial Helm deploy > " YESNO

if [ "$YESNO" = "yes" ];then
    $HELM upgrade -n scot4 \
        --install \
        --reset-values \
        -f OS_values.yaml \
        --set-string scot4.clean_flair_install="true" \
        --set-string scot4.wipe_api_database="true" \
        scot4 ./scot4
else

    echo "Deployment Aborted.  If you wish to manually do the initial deployment, use the following: "
    echo "    (this will cause data loss in the scot4 database if it already exists)"
    cat <<"EOF"

helm upgrade -n scot4 --install --reset-values -f OS_values.yaml --set-string scot4.clean_flair_install="true" --set-string scot4.wipe_api_database="true" scot4 ./scot4

EOF

fi
