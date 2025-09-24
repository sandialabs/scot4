#!/bin/bash 

### install.sh
###     automate installation tasks for SCOT4
###     tbruner@sandia.gov

HELM_VERSION="v3.14.3"          # update to latest version you want
TRAEFIK_MW_VER="v3.3.2"         # update to latest version supported by traefik deployment 
SERVERNAME=""                   # the dns name you plan on using to acces this scot server
REPOSERVER="x"                  # where to get the containers from
REG_SECRET="x"                  # the secret you need (if any) to pull the containers
REG_SECRET_NAME="x"             # the name of the previous secret
AIRFLOW="airflow-server"        # if you have an airflow server, refer to it here
S3SERVER="minio-server"         # if you have a minio or other S3 server
TLS_CRT_FILE=""                 # point to a crt certificate file
TLS_KEY_FILE=""                 # point to a key certificate file
SQLALCHEMY_DATABASE_URI="x"     # set this if you already have a database to use
PAUSE="false"                   # pause the script at strategic points, useful debugging
REPLICAS=1                      # number of api replical pods, 2 for testing on small
                                # vm.  up this to 16 or so for larger production
SURGE=1                         # surge setting, increase this for production
TYPE="OS"

determine_os () {
    if [ -f /etc/redhat-release ]; then
        OS='RHEL'
    fi
    if [ -f /etc/debian_version ]; then
        OS='Ubuntu'
    fi
}

usage() {
    cat <<EOF 1>&2
Usage: $0 [ options ]

    -b REPLICAS        set the number of API server replicas to create
    -c TLS_CRT_FILE    set the fully qualified filename for your TLS Cert file
    -d SQLALCHEMY_URI  set the SQLALCHEMY_DATABASE_URI necessary to connect to your database
                           (only necessary if using an existing DB)
    -e SURGE           set the surge limit for the API server
    -g                 pause script after displaying variables set
    -h HELM_VERSION    sets Helm version to download, defaults to $HELM_VERSION
    -i IPADDR          IP address server will listen on for SCOT traffic
    -k TLS_KEY_FILE    set the fully qualified filename for your TLS Key file
    -m TRAEFIK_MW_VER  set the version for the traefik middleware CRD version
    -n NO_PROXY        set the no_proxy env var (if not set in env)
    -P HTTPS_PROXY     set the proxy for https communications (if not set in env)
    -p HTTP_PROXY      set the proxy for http communications (if not set in env)
    -r REPOSERVER      set the Container Registry Servername[:port]
    -s SERVERNAME      set the servername for this scot instance, usually, scot4
    -t TYPE            OS (default) | dev | qual | prod
    -x REG_SECRET      set the pull secret for the Container Registry
    -y REG_SECRET_NAME the name of the pull secret
EOF
}

determine_os

if [ "$EUID" != "0" ]; then
    echo "!!!! ---- THIS SCRIPT MUST BE RUN AS ROOT! ---- !!!!"
    echo "try: sudo $0"
    exit 1;
fi

while getopts "b:c:d:e:gh:i:k:m:n:P:p:r:s:t:x:y:" options; do
    echo "Option ${options} = ${OPTARG}"
    case "${options}" in
        b)
            REPLICAS=${OPTARG}
            ;;
        c)
            TLS_CRT_FILE=${OPTARG}
            ;;
        d)
            SQLALCHEMY_DATABASE_URI=${OPTARG}
            INTERNAL_DB="false"
            ;;
        e)
            SURGE=${OPTARG}
            ;;
        g)
            PAUSE="true"
            ;;
        h)
            HELM_VERSION=${OPTARG}
            ;;
        i)
            IPADDR=${OPTARG}
            ;;
        k)
            TLS_KEY_FILE=${OPTARG}
            ;;
        m)
            TRAEFIK_MW_VER=${OPTARG}
            ;;
        n)
            NO_PROXY=${OPTARG}
            no_proxy=${OPTARG}
            ;;
        P)
            HTTPS_PROXY=${OPTARG}
            https_proxy=${OPTARG}
	        ;;
        p)
            HTTP_PROXY=${OPTARG}
            http_proxy=${OPTARG}
            ;;
        r)
            REPOSERVER=${OPTARG}
            ;;
        s)
            SERVERNAME=${OPTARG}
            ;;
        t) 
            TYPE=${OPTARG}
            ;;
        x) 
            REG_SECRET=${OPTARG}
            ;;
        y) 
            REG_SECRET_NAME=${OPTARG}
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument."
            usage
            exit 1
            ;;
        *)
            echo "Unknown option provided"
            usage
            exit 1
            ;;
        \?)
            usage
            exit 0
            ;;
    esac
done


# Ask User for Server Name: e.g. scot4-dev
if [ "$SERVERNAME" = "" ]; then
    SERVERDEFAULT=$(hostname)
    echo "==="
    echo "=== Please enter the hostname for your SCOT instance. "
    echo "=== (press enter to use default $SERVERDEFAULT)"
    echo "==="
    read -p 'Server name => ' SERVERNAME
    if [ "$SERVERNAME" = "" ]; then
        SERVERNAME=$SERVERDEFAULT
    fi
fi

if [ "$SERVERNAME" = "localhost.localdomain" ]; then
    echo "--- removing localdomain from hostname $SERVERNAME"
    SERVERNAME="localhost"
fi

# Ask user for location of TLS .crt and .key files
if [ "$TLS_KEY_FILE" = "" ]; then
    echo "==="
    echo "=== Please enter the fully qualified path to your TLS .key file"
    echo "=== (press <enter> to create self-signed cert)"
    echo "==="
    read -p 'KEY File => ' TLS_KEY_FILE
fi
if [ "$TLS_CRT_FILE" = "" ]; then 
    echo "==="
    echo "=== Please enter the fully qualified path to your TLS .crt file"
    echo "=== (press <enter> to create self-signed cert)"
    echo "==="
    read -p 'CRT File => ' TLS_CRT_FILE
fi

if [ "$TLS_CRT_FILE" = "" ] && [ "$TLS_KEY_FILE" = "" ];then
    SD="/home/scot4/.scotssl"
    if [ -f "$SD/$SERVERNAME.crt" ] && [ -f "$SD/$SERVERNAME.csr" ] && [ -f "$SD/$SERVERNAME.key" ]; then
        echo "Using existing self signed certs..."
        TLS_CRT_FILE="$SD/$SERVERNAME.crt"
        TLS_KEY_FILE="$SD/$SERVERNAME.key"
    else
        echo "Self Signed Cert Generation Begins..."
        echo "!!!"
        echo "!!! Note: use $SERVERNAME when prompted for Common Name"
        echo "!!!"

        TARGETDIR="/home/scot4/.scotssl"
        mkdir -p $TARGETDIR
        KEYFILE="$TARGETDIR/$SERVERNAME.key"
        CSRFILE="$TARGETDIR/$SERVERNAME.csr"
        CRTFILE="$TARGETDIR/$SERVERNAME.crt"
        openssl genrsa -out $KEYFILE 2048
        openssl req -key $KEYFILE -new -out $CSRFILE
        openssl x509 -signkey $KEYFILE -in $CSRFILE -req -days 365 -out $CRTFILE
        TLS_CRT_FILE=$CRTFILE
        TLS_KEY_FILE=$KEYFILE
        chown -R scot4 $TARGETDIR
    fi
fi

if [ "$IPADDR" = "" ]; then
    echo "==="
    echo "=== IPADDR not SET.  Select FROM IP addresses below:"
    echo "==="
    PS3="Select Number of IP Address > "
    IPS=$(ip -4 -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}')

    select IPADDR in $IPS
    do
        break
    done
    echo "=== IPADDR selected = $IPADDR"
fi

if [ "$HTTPS_PROXY" = "" ]; then
    echo "==="
    echo "=== HTTPS_PROXY NOT SET.  If you are behind a proxy you will need "
    echo "=== to set this variable.  Press enter to leave it unset."
    echo "==="
    read -p 'HTTPS_PROXY => ' HTTPS_PROXY
    https_proxy="$HTTPS_PROXY"
fi

if [ "$HTTP_PROXY" = "" ]; then
    echo "==="
    echo "=== HTTPS_PROXY NOT SET.  If you are behind a proxy you will need "
    echo "=== to set this variable.  Press enter to leave it unset."
    echo "==="
    read -p 'HTTP_PROXY => ' HTTPS_PROXY
    http_proxy="$HTTP_PROXY"
fi

if [ "$NO_PROXY" = "" ] && [ "$HTTPS_PROXY" = "" ] && [ "$HTTP_PROXY" = "" ]; then
    echo "no proxy is a good proxy" # no need to worry about no_proxy
else
    echo "http(s) proxies set, checking no_proxy"
    if [ "$NO_PROXY" = "" ]; then
        DEFNOPROXY="127.0.0.1,localhost,::1,10.,172.16.,192.168.,*.local,.local,169.254/16,$IPADDR"
        echo "==="
        echo "=== NO_PROXY NOT SET.  If you are behind a proxy you will need "
        echo "=== to set this variable.  Press enter to accept default."
        echo "=== enter 'none' to leave blank"
        echo "=== default = $DEFNOPROXY"
        echo "==="
        read -p 'NO_PROXY => ' NO_PROXY
        if [ "$NO_PROXY" = "" ]; then 
            NO_PROXY=$DEFNOPROXY
        fi
        if [ "$NO_PROXY" = "none" ]; then 
            NO_PROXY=""
        fi
        no_proxy="$NO_PROXY"
    else 
	NO_PROXY="$NO_PROXY,$IPADDR"
    no_proxy="$NO_PROXY"
    fi
fi

# I hate proxies
export NO_PROXY no_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy


echo ""
echo "Installing SCOT4 "
echo "    OS             = $OS"
echo "    Server Name    = $SERVERNAME"
echo "    Helm Version   = $HELM_VERSION"
echo "    TLS CRT FILE   = $TLS_CRT_FILE"
echo "    TLS_KEY_FILE   = $TLS_KEY_FILE"
echo "    SQLAlchemy URI = $SQLALCHEMY_DATABASE_URI"
echo "    HTTPS_PROXY    = $HTTPS_PROXY"
echo "    HTTP_PROXY     = $HTTP_PROXY"
echo "    NO_PROXY       = $NO_PROXY"
echo "    IPADDR         = $IPADDR"
echo "    REPOSERVER     = $REPOSERVER"
echo "    REG_SECRET_NAME = $REG_SECRET_NAME"
echo "    REG_SECRET      = $REG_SECRET"
echo ""

if [ $PAUSE = "true" ];then
    read -p "Enter to proceed..." FOO
fi

if getent passwd scot4 > /dev/null 2>&1; then
    echo "User scot4 already exists..."
else
    echo "Adding scot4 User..."
    useradd -m -s /bin/bash -c "SCOT4 User" scot4
fi

# Install K3s

if ! type k3s >/dev/null 2>/dev/null; then
    echo "Installing k3s..."
    curl -sfLl https://get.k3s.io | 
        INSTALL_K3S_EXEC="--prefer-bundled-bin --disable-cloud-controller" sh -
    if [ $? -ne 0 ]; then
        echo "!!! Download of K3s failed !!!"
        exit 1
    fi
else 
    echo "K3S already installed."
fi

# update /etc/systemd/system/k3s.service.env with proxy information
KENV="/etc/systemd/system/k3s.service.env"
if [ -f $KENV ]; then
    echo "Backing up existing $KENV to $KENV.bak"
    mv $KENV $KENV.bak
fi
cat > $KENV <<EOF 
http_proxy="$http_proxy"
HTTP_PROXY="$HTTP_PROXY"
https_proxy="$https_proxy"
HTTPS_PROXY="$HTTPS_PROXY"
no_proxy="$no_proxy"
NO_PROXY="$NO_PROXY"
EOF
systemctl daemon-reload
systemctl restart k3s

# install traefik middlware CRDs
KUBECTL=/usr/local/bin/kubectl
$KUBECTL apply -f https://raw.githubusercontent.com/traefik/traefik/refs/tags/$TRAEFIK_MW_VER/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml --server-side

# install Helm
if ! type helm >/dev/null 2>/dev/null; then
    echo "Installing Helm..."
    HELM_TAR="helm-$HELM_VERSION-linux-amd64.tar.gz"
    curl -sfl -o /tmp/$HELM_TAR https://get.helm.sh/$HELM_TAR
    if [ $? -ne 0 ]; then
        echo "!!! Download of HELM failed !!!"
        exit 1
    fi
    tar zxvf /tmp/$HELM_TAR -C /tmp
    mv /tmp/linux-amd64/helm /usr/local/bin/helm
else 
    echo "Helm already installed."
fi

# Adjust Firewall rules
# Necessary Firewall Tweaks https://docs.k3s.io/installation/requirements?os=rhel
# The port 6443 rule isn't required as this is a single node install
# if [ "$OS" = "RHEL" ]; then
if [ -e /usr/bin/firewall-cmd ]; then
    # api server
    # firewall-cmd --permanent --add-port=6443/tcp
    # pods
    firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16 
    # services
    firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16 
    firewall-cmd --reload
else
    # Ubuntu
    # api server port
    # uncmment 6443 rule if multi node install
    # ufw allow 6443/tcp 
    # pods
    if [ -e /usr/sbin/ufw ]; then
        ufw allow from 10.42.0.0/16 to any 
        # services
        ufw allow from 10.43.0.0/16 to any 
    else
        echo "ERROR: did not modify firewall because could not determine type"
    fi
fi

if ! type pip; then 
    echo "Installing PIP..."
    if [ "$OS" = "RHEL" ];then
        yum -y install python3-pip
    else
        sudo apt-get -y install python3-pip
    fi
fi

# Install kubectl tab-completion and allow alias to work as well
BASHRC=/home/scot4/.bashrc
mkdir -p ~scot4/.kube
cp /etc/rancher/k3s/k3s.yaml ~scot4/.kube/config
chown -R scot4:scot4 ~scot4/.kube


echo "Examining $BASHRC for alias and tab completions"
if ! grep -q "KUBECONFIG" $BASHRC; then
    echo "export KUBECONFIG=~scot4/.kube/config" >> $BASHRC
    export KUBECONFIG="~scot4/.kube/config"
fi
if ! grep -q "alias k=$KUBECTL" $BASHRC; then
	echo "alias k=$KUBECTL" >> $BASHRC 
fi
if ! grep -q "source <($KUBECTL" $BASHRC; then
	echo "source <($KUBECTL completion bash)" >> $BASHRC
fi
if ! grep -q "complete -o default -F __start_kubectl k" $BASHRC; then 
	echo "complete -o default -F __start_kubectl k" >> $BASHRC
fi
if ! grep -q "$KUBECTL config set-context" $BASHRC; then
	echo "$KUBECTL config set-context --current --namespace=scot4" >> $BASHRC
fi
chown -R scot4:scot4 /home/scot4/.bashrc

# Disable swap because kubernetes likes that off
echo "Disabling swap, because thats how Kubernetes likes to roll"
swapoff -a
# find any line with swap in it and place one # at the beginning of the line
sed -e '/swap/ s/^#*/#/' -i /etc/fstab

# run rest of script as scot4 user
sudo -i -u scot4 ~scot4/scot4/install2.sh \
    -a $AIRFLOW \
    -b $REPLICAS \
    -c $TLS_CRT_FILE \
    -d $SQLALCHEMY_DATABASE_URI \
    -e $SURGE \
    -k $TLS_KEY_FILE \
    -m $S3SERVER  \
    -n $REG_SECRET_NAME \
    -r $REPOSERVER \
    -s $SERVERNAME \
    -t $REG_SECRET \
    -v $TYPE

exit 0

