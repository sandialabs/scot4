#!/bin/bash

set_defaults () {
    BASHRC=/home/scot4/.bashrc
    K3S_VERSION="v1.36.4+k3s1"
    K3S_INSTALLER_URL="https://raw.githubusercontent.com/k3s-io/k3s/v1.36.4%2Bk3s1/install.sh"
    K3S_INSTALLER_SHA256="46177d4c99440b4c0311b67233823a8e8a2fc09693f6c89af1a7161e152fbfad"
    HELM_VERSION="v4.3.0"
    HELM_SHA256="86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb"

    # pick up the server's name
    SERVERNAME=$(hostname)

    # Vars to access repository container images
    REPOSERVER="x"
    REPOPATH="x"
    REG_SECRET="x"
    REG_SECRET_NAME="x"

    # if you know and wish to use a AirFlow Server or S3 File server
    AIRFLOW="airflow-server"
    S3SERVER="minio-server"

    # TLS Files
    TLS_CRT_FILE=""
    TLS_KEY_FILE=""

    # if you are going to use an existing database external to SCOT
    # set the sql alchemy uri here
    SQLALCHEMY_DATABASE_URI="x"

    # Number of API replicas to create, 2 for testing.  More depending on number of users
    REPLICAS=1

    # surge setting for fastapi
    SURGE=1

    # Set the type of install OS (default) | dev | qual | prod ... 
    SCOT_INSTANCE_TYPE="OS"

    # set this to "true" if you want the install script to pause at 
    # strategic points
    PAUSE="false"

    # pick up proxy settings from environment
    # HTTP_PROXY=$http_proxy
    # HTTPS_PROXY=$https_proxy
    # NO_PROXY=$no_proxy

    # program shortcuts
    KUBECTL=/usr/local/bin/kubectl
    HELM=/usr/local/bin/helm
    NAMESPACE="scot4"
    export CONTAINERD_LOG_LEVEL=debug
    KUBECONFIGDIR=/home/scot4/.kube
    export KUBECONFIG=$KUBECONFIGDIR/config
}

INSTALL_TMP_DIR=""

cleanup_install_tmp_dir () {
    if [ -n "$INSTALL_TMP_DIR" ] && [ -d "$INSTALL_TMP_DIR" ]; then
        rm -rf -- "$INSTALL_TMP_DIR"
    fi
}

ensure_install_tmp_dir () {
    if [ -z "$INSTALL_TMP_DIR" ]; then
        INSTALL_TMP_DIR=$(mktemp -d /tmp/scot4-install.XXXXXXXX)
        if [ -z "$INSTALL_TMP_DIR" ] || [ ! -d "$INSTALL_TMP_DIR" ]; then
            echo "    !!! Unable to create a private temporary directory !!!"
            return 1
        fi
    fi
}

download_verified_file () {
    local url=$1
    local destination=$2
    local expected_sha256=$3

    if ! curl -fsSL --output "$destination" "$url"; then
        echo "    !!! Download failed: $url !!!"
        return 1
    fi

    if ! printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum --check --status; then
        echo "    !!! SHA-256 verification failed: $destination !!!"
        echo "    Expected: $expected_sha256"
        echo "    Actual:   $(sha256sum "$destination" | awk '{print $1}')"
        return 1
    fi
}

trap cleanup_install_tmp_dir EXIT

output_variables () {
    echo "---"
    echo "--- SCOT4 Install Variables "
    echo "---"
    echo "    BASE_DIR        = $BASE_DIR"
    echo "    OS              = $OS"
    echo "    K3s Version     = $K3S_VERSION"
    echo "    Server Name     = $SERVERNAME"
    echo "    Helm Version    = $HELM_VERSION"
    echo "    TLS CRT FILE    = $TLS_CRT_FILE"
    echo "    TLS_KEY_FILE    = $TLS_KEY_FILE"
    echo "    SQLAlchemy URI  = $SQLALCHEMY_DATABASE_URI"
    echo "    HTTPS_PROXY     = $HTTPS_PROXY"
    echo "    HTTP_PROXY      = $HTTP_PROXY"
    echo "    NO_PROXY        = $NO_PROXY"
    echo "    IPADDR          = $IPADDR"
    echo "    REPOSERVER      = $REPOSERVER"
    echo "    REPOPATH        = $REPOPATH"
    echo "    REG_SECRET_NAME = $REG_SECRET_NAME"
    echo "    REG_SECRET      = $REG_SECRET"
    echo "    AIRFLOW         = $AIRFLOW"
    echo "    S3SERVER        = $S3SERVER"
    echo ""
}


if [ "$EUID" != "0" ];then
    echo "!!!! ERROR: this script must be run as root !!!!"
    echo "     try: sudo $0"
    exit 1
fi

echo "---"
echo "--- Determining Script absolute directory..."
echo "---"

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "${SCRIPT_PATH}" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
    SCRIPT_PATH="$(readlink "${SCRIPT_PATH}")"
    [[ "${SCRIPT_PATH}" != /* ]] && SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_PATH}"
done
SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
BASE_DIR=$SCRIPT_DIR
INSTFUNC=$BASE_DIR/inst_func

echo "    BASE_DIR = $BASE_DIR"

echo "---"
echo "--- Determining Operating System..."
echo "---"

if [ -f /etc/redhat-release ]; then
    OS='RHEL'
    SUDO_GROUP_NAME="wheel"
fi
if [ -f /etc/debian_version ]; then
    OS='Ubuntu'
    SUDO_GROUP_NAME="sudo"
fi
echo "    OS = $OS"

echo "---"
echo "--- checking correct HOME environment var"
echo "---"
if [ "$HOME" != "/home/scot4" ]; then
    echo "??? weirdly HOME not set to /home/scot4"
    echo "    home was $HOME"
    echo "    reseting HOME ..."
    export HOME=/home/scot4
fi

echo "    HOME = $HOME"

set_defaults

echo "---"
echo "--- Parsing Command Line..."
echo "---"
while getopts "a:b:c:d:e:gi:k:n:P:p:r:R:s:t:v:x:y:" opt "$@"; do
    case "${opt}" in
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
            INTERNAL_DB="false"
            ;;
        e)
            SURGE=${OPTARG}
            ;;
        g)
            PAUSE="true"
            ;;
        i)
            IPADDR=${OPTARG}
            ;;
        k)
            TLS_KEY_FILE=${OPTARG}
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
        R)
            REPOPATH=${OPTARG}
            ;;
        s) 
            SERVERNAME=${OPTARG}
            ;;
        t)
            SCOT_INSTANCE_TYPE=${OPTARG}
            ;;
        v)
            VARIANT=${OPTARG}
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
            echo "Error: Unknown option provided"
            usage
            exit 1
            ;;
        \?)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

echo "---"
echo "--- Determining server name..."
echo "---"

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
echo "    SERVERNAME = $SERVERNAME"

echo "---"
echo "--- Setting up TLS..."
echo "---"

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
    if [ -L "$SD" ]; then
        echo "    !!! Refusing to use symbolic link for self-signed TLS directory $SD !!!"
        exit 1
    fi

    if ! mkdir -p "$SD" || ! chown scot4:scot4 "$SD" || ! chmod 700 "$SD"; then
        echo "    !!! Failed to secure self-signed TLS directory $SD !!!"
        exit 1
    fi

    for TLS_FILE in "$SD/$SERVERNAME.crt" "$SD/$SERVERNAME.csr" "$SD/$SERVERNAME.key"; do
        if [ -L "$TLS_FILE" ]; then
            echo "    !!! Refusing to use symbolic link for self-signed TLS file $TLS_FILE !!!"
            exit 1
        fi
    done

    if [ -f "$SD/$SERVERNAME.crt" ] && [ -f "$SD/$SERVERNAME.csr" ] && [ -f "$SD/$SERVERNAME.key" ]; then
        echo "Using existing self signed certs..."
        TLS_CRT_FILE="$SD/$SERVERNAME.crt"
        TLS_KEY_FILE="$SD/$SERVERNAME.key"

        if ! chown scot4:scot4 "$TLS_CRT_FILE" "$SD/$SERVERNAME.csr" "$TLS_KEY_FILE" || ! chmod 600 "$TLS_KEY_FILE"; then
            echo "    !!! Failed to secure existing self-signed TLS files !!!"
            exit 1
        fi
    else
        echo "Self Signed Cert Generation Begins..."
        echo "!!!"
        echo "!!! Note: use $SERVERNAME when prompted for Common Name"
        echo "!!!"

        TARGETDIR="/home/scot4/.scotssl"
        KEYFILE="$TARGETDIR/$SERVERNAME.key"
        CSRFILE="$TARGETDIR/$SERVERNAME.csr"
        CRTFILE="$TARGETDIR/$SERVERNAME.crt"

        if ! (
            umask 077
            openssl genrsa -out "$KEYFILE" 2048 &&
                chmod 600 "$KEYFILE" &&
                openssl req -key "$KEYFILE" -new -out "$CSRFILE" &&
                openssl x509 -signkey "$KEYFILE" -in "$CSRFILE" -req -days 365 -out "$CRTFILE"
        ); then
            echo "    !!! Self-signed TLS certificate generation failed !!!"
            exit 1
        fi

        if ! chown scot4:scot4 "$KEYFILE" "$CSRFILE" "$CRTFILE" || ! chmod 600 "$KEYFILE"; then
            echo "    !!! Failed to secure generated self-signed TLS files !!!"
            exit 1
        fi

        TLS_CRT_FILE=$CRTFILE
        TLS_KEY_FILE=$KEYFILE
    fi
fi

echo "---"
echo "--- Determining IP address..."
echo "---"
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
    echo "    IPADDR = $IPADDR"
fi

echo "---"
echo "--- Determining Proxy Settings..."
echo "---"
if [[ "$https_proxy" == "" && "$HTTPS_PROXY" == "" ]]; then
    echo "==="
    echo "=== Neither HTTPS_PROXY nor https_proxy is set in environment"
    echo "===   if you are behind a proxy, you will need to set this variable."
    echo "===   Enter proxy or press enter to leave the variable unset"
    echo "==="
    read -p 'HTTPS_PROXY => ' HTTPS_PROXY
    https_proxy=$HTTPS_PROXY
else
    if [[ "$https_proxy" != "$HTTPS_PROXY" ]]; then
        if [[ "$https_proxy" != "" && "$HTTPS_PROXY" == "" ]]; then
            echo "https_proxy is set but HTTPS_PROXY is unset.  Setting HTTPS_PROXY to match."
            HTTPS_PROXY=$https_proxy
        fi
        if [[ "$https_proxy" == "" && "$HTTPS_PROXY" != "" ]]; then
            echo "HTTPS_PROXY is set but https_proxy is unset.  Setting https_proxy to match."
            https_proxy=$HTTPS_PROXY
        fi
    fi
fi

if [[ "$http_proxy" == "" && "$HTTP_PROXY" == "" ]]; then
    echo "==="
    echo "=== Neither HTTP_PROXY nor http_proxy is set in environment"
    echo "===   if you are behind a proxy, you will need to set this variable."
    echo "===   Enter proxy or press enter to leave the variable unset"
    echo "==="
    read -p 'HTTP_PROXY => ' HTTP_PROXY
    http_proxy=$HTTP_PROXY
else
    if [[ "$http_proxy" != "$HTTP_PROXY" ]]; then
        if [[ "$http_proxy" != "" && "$HTTP_PROXY" == "" ]]; then
            echo "http_proxy is set but HTTP_PROXY is unset.  Setting HTTP_PROXY to match."
            HTTPS_PROXY=$https_proxy
        fi
        if [[ "$https_proxy" == "" && "$HTTPS_PROXY" != "" ]]; then
            echo "HTTP_PROXY is set but http_proxy is unset.  Setting http_proxy to match."
            http_proxy=$HTTP_PROXY
        fi
    else
        echo "HTTP proxy set and matching"
    fi
fi


if [ "$NO_PROXY" = "" ] && [ "$HTTPS_PROXY" = "" ] && [ "$HTTP_PROXY" = "" ]; then
    echo "no proxy is a good proxy" # no need to worry about no_proxy
else
    echo "http(s) proxies set, checking no_proxy"
    if [ "$NO_PROXY" = "" ]; then
        HNAME=$(hostname)
        DEFNOPROXY="$HNAME,127.0.0.1,localhost,::1,10.,172.16.,192.168.,*.local,.local,169.254/16,$IPADDR"
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

export NO_PROXY no_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy

echo "---"
echo "--- Adjusting Firewall Rules..."
echo "---"
# Adjust Firewall rules
# Necessary Firewall Tweaks https://docs.k3s.io/installation/requirements?os=rhel
if [ -e /usr/bin/firewall-cmd ]; then
    FWSTATUS=$(systemctl is-active firewalld)
    if [ "$FWSTATUS" == "active" ]; then
        # pods
        firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16 
        # services
        firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16 
        firewall-cmd --reload
    else
        echo "    Firewalld is not active, skipping addition of firewall rules"
    fi
else
    if [ -e /usr/sbin/ufw ]; then
        if ufw status | grep -qw active; then
            ufw allow from 10.42.0.0/16 to any  # pods
            ufw allow from 10.43.0.0/16 to any  # services
        else
            echo "    UFW is not active, skipping additon of firewall rules"
        fi
    else
        echo "!!!"
        echo "!!! WARNING: did not modify firewall because could not determine type"
        echo "!!!    If you are running a firewall on this system, "
        echo "!!!    and SCOT fails to install or work after install," 
        echo "!!!    this could be why."
        echo "!!!"
    fi
fi


output_variables

echo "---"
echo "--- Creating SCOT4 user if necessary..."
echo "---"
if getent passwd "scot4" > /dev/null 2>&1; then
    echo "    scot4 already exists"
else
    if useradd -m -s /bin/bash -c "SCOT4 User" scot4; then
        echo "    created scot4 user"
    else
        echo "    !!! Failed to create scot4 user !!!"
        exit 2
    fi
fi
if id -Gn "scot4" | grep -qw "$SUDO_GROUP_NAME"; then
    echo "scot4 already in group $SUDO_GROUP_NAME"
else
    if usermod -aG $SUDO_GROUP_NAME scot4; then
        echo "    Added scot4 to $SUDO_GROUP_NAME"
    else
        echo "    !!! Failed to add scot4 to $SUDO_GROUP_NAME !!!"
        exit 3
    fi
fi
    
echo "---"
echo "--- Adding PROXY vars to env files if necessary..."
echo "---"
for ENVFILE in /home/scot4/.bashrc /etc/environment; do
    if ! grep -q "HTTP_PROXY=" $ENVFILE; then
        echo "HTTP_PROXY=$HTTP_PROXY" >> $ENVFILE
    fi
    if ! grep -q "HTTPS_PROXY=" $ENVFILE; then
        echo "HTTPS_PROXY=$HTTPS_PROXY" >> $ENVFILE
    fi
    if ! grep -q "http_proxy=" $ENVFILE; then
        echo "http_proxy=$http_proxy" >> $ENVFILE
    fi
    if ! grep -q "https_proxy=" $ENVFILE; then
        echo "https_proxy=$https_proxy" >> $ENVFILE
    fi
    if ! grep -q "NO_PROXY=" $ENVFILE; then
        echo "NO_PROXY=$NO_PROXY" >> $ENVFILE
    fi
    if ! grep -q "NO_PROXY=" $ENVFILE; then
        echo "no_proxy=$no_proxy" >> $ENVFILE
    fi
done

echo "---"
echo "--- Disabling SWAP, because that's how kubernetes likes to roll..."
echo "---"
swapoff -a
sed -e '/swap/ s/^#*/#/' -i /etc/fstab



echo "---"
echo "--- checking selinux status"
echo "---"
SE_ENABLED=$(sestatus | grep 'SELinux status' | awk '{print $3}')

if [ "$SE_ENABLED" == "enabled" ]; then
    echo "    SELinux is enabled"
    SELINUX="--selinux"
    # no longer necessary with helm fix
    #ENFORCING=$(getenforce)
    #if [ "$ENFORCING" == "Enforcing" ];then
      #  echo "    SELinux in enforcing mode, setting to permissive mode..."
      #  setenforce 0
    #    sestatus
      #  DISABLEDSE="yes"
    #else
    #    echo "    SELinux in permissive mode"
    #    DISABLEDSE="no"
    #fi
else
    echo "    SELinux disabled"
    SELINUX=""
fi


echo "---"
echo "--- Installing K3S..."
echo "---"
if ! type /usr/local/bin/k3s >/dev/null 2>/dev/null; then
    echo "Installing k3s..."
    if ! ensure_install_tmp_dir; then
        exit 4
    fi

    K3S_INSTALLER="$INSTALL_TMP_DIR/install-k3s.sh"
    if ! download_verified_file "$K3S_INSTALLER_URL" "$K3S_INSTALLER" "$K3S_INSTALLER_SHA256"; then
        echo "    !!! Secure download of K3s installer failed !!!"
        exit 4
    fi

    if ! INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_EXEC="--prefer-bundled-bin --disable-cloud-controller $SELINUX" sh "$K3S_INSTALLER"; then
        echo "    !!! Installation of K3s failed !!!"
        exit 4
    fi
else 
    INSTALLED_K3S_VERSION=$(/usr/local/bin/k3s --version 2>/dev/null | awk 'NR == 1 {print $3}')
    echo "    K3s is already installed; leaving it unchanged."
    echo "    Installed version: ${INSTALLED_K3S_VERSION:-unknown}"
    echo "    Installer version: $K3S_VERSION"
    if [ "$INSTALLED_K3S_VERSION" != "$K3S_VERSION" ]; then
        echo "    To upgrade, first back up the cluster and review:"
        echo "    https://docs.k3s.io/upgrades/manual"
        echo "    Use the pinned installer at $K3S_INSTALLER_URL"
        echo "    and verify its SHA-256 is $K3S_INSTALLER_SHA256 before running it."
        echo "    Then run the verified file with INSTALL_K3S_VERSION=$K3S_VERSION"
        echo "    and INSTALL_K3S_EXEC='--prefer-bundled-bin --disable-cloud-controller $SELINUX'."
    fi
fi

echo "---"
echo "--- Setting up Kubectl aliases..."
echo "---"
if [ -L "$KUBECONFIGDIR" ]; then
    echo "    !!! Refusing to use symbolic link for kubeconfig directory $KUBECONFIGDIR !!!"
    exit 1
fi

if [ -L "$KUBECONFIG" ]; then
    echo "    !!! Refusing to overwrite symbolic link at $KUBECONFIG !!!"
    exit 1
fi

if ! mkdir -p "$KUBECONFIGDIR" || ! chown scot4:scot4 "$KUBECONFIGDIR" || ! chmod 700 "$KUBECONFIGDIR"; then
    echo "    !!! Failed to secure kubeconfig directory $KUBECONFIGDIR !!!"
    exit 1
fi

if ! install -o scot4 -g scot4 -m 0600 /etc/rancher/k3s/k3s.yaml "$KUBECONFIG"; then
    echo "    !!! Failed to install kubeconfig $KUBECONFIG !!!"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG"
ls -ld "$KUBECONFIGDIR"
ls -l "$KUBECONFIG"


KENV="/etc/systemd/system/k3s.service.env"
echo "---"
echo "--- update $KENV with proxy information..."
echo "---"
if [ -f $KENV ]; then
    echo "    Backing up existing $KENV to $KENV.bak"
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

echo "=== reloading systemctl config"
if systemctl daemon-reload;then 
    echo "    reloaded systemctl daemon"
else
    echo "    failed to reload systemctl"
    exit 1
fi

echo "=== restarting k3s"
if systemctl restart k3s; then
    echo "    restarted k3s"
else
    echo "    failed to restart k3s"
    exit 1
fi


echo "=== testing k3s readiness"
export KUBECTL=/usr/local/bin/kubectl
# whoami
# echo "kubeconfig = $KUBECONFIG"
TRYCOUNT=0
until $KUBECTL get ns; do
    echo "    kubectl may not be ready yet..."
    sleep 5
    TRYCOUNT=$((TRYCOUNT + 1))
    if [ $TRYCOUNT -ge 10 ]; then
        echo "    !!! giving up after 10 tries."
        echo ""
        echo "    k3s install may have had an error.  Try these step:"
        echo "        1. uninstall k3s.   sudo /usr/local/bin/k3s-uninstall.sh"
        echo "        2. remove dir.      sudo rm -rf /etc/rancher/node"
        echo "        3. restart install. sudo ./install.sh"
        echo ""
        exit 1
    fi
done

echo "=== awaiting completion of traefik CRD and controller installs"
for TRAEFIK_JOB in helm-install-traefik-crd helm-install-traefik; do
    TRYCOUNT=0
    until $KUBECTL -n kube-system get "job/$TRAEFIK_JOB" >/dev/null 2>&1; do
        echo "    Waiting for $TRAEFIK_JOB to be created..."
        sleep 15
        TRYCOUNT=$((TRYCOUNT + 1))
        if [ $TRYCOUNT -ge 20 ]; then
            echo "    !!! $TRAEFIK_JOB was not created within five minutes."
            exit 1
        fi
    done

    if ! $KUBECTL -n kube-system wait --for=condition=complete "job/$TRAEFIK_JOB" --timeout=10m; then
        echo "    !!! $TRAEFIK_JOB did not complete successfully."
        exit 1
    fi
done

if ! $KUBECTL wait --for=condition=Established crd/middlewares.traefik.io --timeout=2m; then
    echo "    !!! Traefik Middleware CRD was not established."
    exit 1
fi

if ! $KUBECTL -n kube-system rollout status deployment/traefik --timeout=5m; then
    echo "    !!! Traefik deployment did not become ready."
    exit 1
fi

echo "    Traefik CRDs and controller are ready"


echo "---"
echo "--- Installing HELM..."
echo "---"
if ! type /usr/local/bin/helm >/dev/null 2>/dev/null; then
    echo "    Installing Helm..."
    HELM_TAR="helm-$HELM_VERSION-linux-amd64.tar.gz"
    if ! ensure_install_tmp_dir; then
        exit 5
    fi

    HELM_ARCHIVE="$INSTALL_TMP_DIR/$HELM_TAR"
    if ! download_verified_file "https://get.helm.sh/$HELM_TAR" "$HELM_ARCHIVE" "$HELM_SHA256"; then
        echo "    !!! Secure download of Helm failed !!!"
        exit 5
    fi

    if ! tar -xzf "$HELM_ARCHIVE" -C "$INSTALL_TMP_DIR"; then
        echo "    !!! Extraction of Helm failed !!!"
        exit 5
    fi

    if ! install -o root -g root -m 0755 "$INSTALL_TMP_DIR/linux-amd64/helm" /usr/local/bin/helm; then
        echo "    !!! Installation of Helm failed !!!"
        exit 5
    fi
else 
    INSTALLED_HELM_VERSION=$(/usr/local/bin/helm version --short 2>/dev/null | awk '{print $1}')
    echo "    Helm is already installed; leaving it unchanged."
    echo "    Installed version: ${INSTALLED_HELM_VERSION:-unknown}"
    echo "    Installer version: $HELM_VERSION"
fi


echo "---"
echo "--- Installing Pip3..."
echo "---"
if ! type pip3; then 
    if [ "$OS" = "RHEL" ];then
        INST_YUM_CMD="sudo yum -y install python3-pip"
    else
        INST_YUM_CMD="sudo apt-get -y install python3-pip"
    fi
    if $INST_YUM_CMD; then
        echo "installed pip3" 
    else
        echo "FAILED pip3 install!"
        exit 6
    fi
fi


echo "---"
echo "--- Checking PyYAML status..."
echo "---"
PYYAMLVER=$(python3 -m pip freeze | grep -i pyyaml | awk -F== '{print $2}')
PYYAMLMAJ=$(echo $PYYAMLVER | awk -F. '{print $1}')

echo "    pyYaml version = $PYYAMLVER"
echo "    pyYaml major   = $PYYAMLMAJ"

if [ "$PYYAMLMAJ" == "" ] || [ "$PYYAMLMAJ" -lt 5 ]; then
    echo "Upgrading PyYAML..."
    if python3 -m pip install --upgrade PyYAML; then
        echo "    PyYAML upgraded"
    else 
        echo "    !!! PyYAML upgrade FAILED"
        exit 1
    fi
fi


echo "---"
echo "--- Examining $BASHRC for alias and tab completions"
echo "---"
if ! grep -q "KUBECONFIG" $BASHRC; then
    echo "export KUBECONFIG=$KUBECONFIG" >> $BASHRC
    export KUBECONFIG=$KUBECONFIG
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
chown -R scot4:scot4 $BASHRC
echo  "    Updated aliases"

RUNAS="sudo -E -u scot4"
echo "---"
echo "--- Creating $NAMESPACE namespace in k3s as user scot4..."
echo "---"

$RUNAS $INSTFUNC/inst_create_k_namespace.sh $NAMESPACE

if [ $? != 0 ]; then
    echo "!!! FAILED to create $NAMESPACE namespace !!!"
    exit 7
fi

echo "---"
echo "--- Creating TLS secret..."
echo "---"
$RUNAS $INSTFUNC/inst_create_tls_secret.sh $NAMESPACE $TLS_KEY_FILE $TLS_CRT_FILE

if [ $? != 0 ]; then
    echo "    !!! FAILED to save scot4-tls !!!"
    exit 8
fi

echo "---"
echo "--- Applying Secrets..."
echo "---"
$RUNAS $INSTFUNC/inst_apply_k_secrets.sh $SQLALCHEMY_DATABASE_URI $BASE_DIR

if [ $? != 0 ]; then
    echo "    !!! FAILED to apply scot4 secrets !!!"
    exit $? 
fi

echo "---"
echo "--- Merging registry secrets..."
echo "---"
$RUNAS $INSTFUNC/inst_merge_secrets.sh $REG_SECRET $REG_SECRET_NAME $REPOSERVER $NAMESPACE

if [ $? != 0 ]; then
    echo "    !!! FAILED to merge secrets!!!"
    exit $? 
fi

echo "---"
echo "--- Updating values yaml..."
echo "---"
UPVALOPTS="$BASE_DIR $REPOSERVER $REPOPATH $SERVERNAME $AIRFLOW $S3SERVER $REPLICAS $SURGE $SQLALCHEMY_DATABASE_URI"
echo "VALOPTS = $UPVALOPTS"
$RUNAS $INSTFUNC/inst_update_values.sh $UPVALOPTS

echo "||| WARNING: This final step of the install CAN CAUSE DATA LOSS."
echo "|||          If you select \"clean install\" below, the SCOT4 database"
echo "|||          will be wiped and re-initialized."
echo "|||"
echo "||| Option Descriptions: "
echo "|||    clean        => appropriate for 1st time installs or when you wish to "
echo "|||                    erase everything and start fresh. (DATA LOSS, have a backup!)"
echo "|||"
echo "|||    redeploy     => you just want helm to pick up changes to the chart and redeply."
echo "|||                    (will not destroy existing database)"
echo "|||"
echo "|||    modify       => you wish to enter the command line parameters to the helm command."
echo "|||                    (depending on your options, you may or may not cause data loss)"
echo "|||"
echo "|||    quit         => stop without having helm deploy SCOT."

PS3="Select deployment option > "
select dopt in clean redeploy modify quit; do
    case $dopt in
        clean)
            $RUNAS $INSTFUNC/inst_clean_upgrade_chart.sh $HELM
            break
            ;;
        redeploy)
            ./redeploy.sh
            break
            ;;
        modify)
            $RUNAS $INSTFUNC/inst_modupgrade_chart.sh $HELM
            break
            ;;
        quit)
            exit 0
            ;;
        *)
            echo "Invalid option: $REPLY"
            ;;
    esac
done


# echo ""
# echo "If you wish to monitor their progress, enter \"yes\" below."
#read -p "Monitor POD setup? " MONSETUP

#if [ "$MONSETP" == "yes" ]; then
#    $RUNAS $BASE_DIR/inst_monitor.sh
#fi

source ~scot4/.bashrc
echo "---"
echo "--- Installation Script Complete "
echo "---"
echo "    Deployment complete, however, it may take several minutes for "
echo "    the pods to spin up."
echo ""
echo "    To monitor pod start-up, run the following commands:"
echo "        $ source ~scot4/.bashrc"
echo "        $ watch kubectl get pods"
echo "    <ctrl-c> when all pods are in Running state."
echo ""
echo "    You may have to accept the invalid cert if you choose to create "
echo "    a self-signed certificate."
echo ""
PW=$($KUBECTL -n scot4 get secret scot4-env-secrets -o jsonpath='{.data.FIRST_SUPERUSER_PASSWORD}'| base64 --decode;)
echo "---"
echo "--- Initial SCOT Login information"
echo "--- "
echo "     URL   =   https://$SERVERNAME"
echo "    USER   =   scot-admin"
echo "PASSWORD   =   $PW"

#if [ "$DISABLEDSE" == "yes" ]; then
#    echo "Re-enabling selinux"
#    setenforce 1
#fi

exit 0
