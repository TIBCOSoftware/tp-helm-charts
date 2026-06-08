#!/usr/bin/env bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# set -x
#############################################################3
export DPCLI_KUBECONFIG="${HOME}/.kube/_dpinstall_.yaml"
export SUDO_ENV_VARS="KUBECONFIG,PATH"
exists () {
  [ -f "$1" ] >/dev/null 2>&1
  return $?
}

exists_function() {
    declare -f "${1}" >/dev/null
    return $?
}

exists_in_path () {
    if type -P "${1}" &> /dev/null; then
        # echo "Command found"
        return 0
    else
        # echo "Command not found"
        return 1
    fi

    # IFS=:
    # for d in $PATH; do
    #   if [ -x "$d/$1" ]; then
    #     return 0
    #   fi
    # done
    # return 1
 }

############### Check if kubectl in $PATH ##################
checkKubeCtlExists() {
    exists_in_path kubectl
    [ $? != 0 ] && return 1
    exists_function kubectl
    [ $? != 0 ] && return 1
    return 0
}
############### Check if kubectl in $PATH ##################
checkHelmExists() {
    exists_in_path helm
    [ $? == 0 ] && return 0
    exists_function helm
    [ $? == 0 ] && return 0
    return 1
}

############ Check if KUBECONFIG env var is set #############
checkKubeConfig() {
    if [ -n "${KUBECONFIG}" ]; then
    # check if the config file pointed by the var exists
      exists "${KUBECONFIG}"
      if [ $? == 0 ]; then
         return 0
      fi
    else
        # check if the microk8s generated kubeconfig exists
        [ -r "${DPCLI_KUBECONFIG}" ]
        if [ $? == 0 ]; then
            KUBECONFIG="${DPCLI_KUBECONFIG}"
            return 0
        fi
        # check if the default kube config exists
        [ -r "${HOME}/.kube/config" ]
        if [ $? == 0 ]; then
            KUBECONFIG="${HOME}/.kube/config"
            return 0
        fi
    fi
    return 1
}
############# getMachineOS ####################
getMachineOS() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine=Linux;;
        Darwin*)    machine=Mac;;
        CYGWIN*)    machine=Cygwin;;
        MINGW*)     machine=MinGw;;
        MSYS_NT*)   machine=MSys;;
        *)          machine="UNKNOWN:${unameOut}"
    esac
    echo ${machine}
}
############# check if Ubuntu Linux ################
checkUbuntu() {
   machineOS=$(getMachineOS)
   if [ "Linux" == ${machineOS} ]; then
      os_name=$(grep '^NAME' /etc/os-release | sed 's/"//g')
      os_name="${os_name##*=}"
      [ "Ubuntu" == "${os_name}" ] && return 0 || return 1
   fi
   return 1
}
############### check linux ##########################
checkLinux() {
    machineOS=$(getMachineOS)
   if [ "Linux" == ${machineOS} ]; then
      return 0
   fi
   return 1
}
############# check snap is installed #################
checkSnapExists() {
    exists_in_path snap
    rc=$?
    return $rc
}
############# check micorK8s is installed #################
checkMicroK8sExists() {
    elevate_cmd env snap list | grep -i "^microk8s.*classic" >/dev/null 2>&1
    rc=$?
    return $rc
}
############# show cluster info ########################
showClusterInfo() {
    echo ""
    kubectl cluster-info
    echo ""
}

################ check if user is root #################
is_root () {
    return $(id -u)
}
################ check if user has sudo access ################
has_sudo() {
    local prompt
    [ ! -z ${SILENT_MODE} ] && echo "has_silent_mode" && return
    prompt=$(sudo -nv 2>&1)
    if [ $? -eq 0 ]; then
    echo "has_sudo__pass_set"
    elif echo $prompt | grep -q '^sudo:'; then
    echo "has_sudo__needs_pass"
    else
    echo "no_sudo"
    fi
}
############### elevate to super user access ####################
elevate_cmd () {
    # set -x
    local cmd=$@

    HAS_SUDO=$(has_sudo)
    [ -n "${SUDO_ENV_VARS}" ] && PRESERVE_ENV="--preserve-env=${SUDO_ENV_VARS}"
    case "$HAS_SUDO" in
    has_silent_mode)
        echo -e ${SUDO_PASSWORD} | sudo -E -S ${PRESERVE_ENV} $cmd
        ;;
    has_sudo__pass_set)
        sudo ${PRESERVE_ENV} -E $cmd
        ;;
    has_sudo__needs_pass)
        echo "Please supply sudo password for the following command: sudo $cmd"
        sudo ${PRESERVE_ENV} $cmd
        ;;
    *)
        echo "Please supply root password for the following command: su -c \"$cmd\""
        su -c "$cmd"
        ;;
    esac
    # set +x
}
#################### exit if root user #########################
exit_root_user() {
    if is_root; then
        echo "[ERROR] Need to call this script as a normal user, not as root!"
        exit 1
    fi
}

#################### install microk8s #########################
install_microk8s() {
    elevate_cmd env snap find microk8s | grep -i "microk8s.*canonical.*classic" 2>&1
    if [ $? == 0 ]; then
        elevate_cmd env snap list | grep -i "^microk8s.*classic"
        if [ $? != 0 ]; then
            echo "[INFO] Installing microk8s snap package."
            elevate_cmd env snap install --stable --classic microk8s
        else
            echo "[INFO] microk8s is already installed."
        fi
    else
        echo "[INFO] microk8s snap package not found in repository."
    fi
}
##################### set microk8s permissions ###############
set_microk8s_permissions() {
    elevate_cmd usermod -a -G microk8s $USER
    mkdir -p ~/.kube
    elevate_cmd chmod 0755 ~/.kube
    export PATH=/var/snap/bin:$PATH
}
###################### uninstall microk8s ####################
uninstall_microk8s() {
    elevate_cmd env snap list | grep -i "^microk8s.*classic"
    if [ $? == 0 ]; then
        echo "[INFO] Uninstalling microk8s snap package"
        elevate_cmd env snap remove --purge microk8s
    else
        echo "[INFO] microk8s is not installed"
    fi
}
################# kubectl function as alias ########
kubectl() {
    elevate_cmd env microk8s kubectl $@
}
################# helm command as alias ###########
helm() {
    elevate_cmd env microk8s helm $@
}
############## generate microk8s kubeconfig ###############
generateMicroK8sKubeConfig() {
    checkMicroK8sExists
    if [ $? == 0 ]; then
        elevate_cmd rm -f  ${DPCLI_KUBECONFIG}
        elevate_cmd env microk8s config > ${DPCLI_KUBECONFIG}
        rc=$?
    fi
    return ${rc}
}
################ check if microk8s is running ######
isMicrok8sRunning() {
    isRunning=$(elevate_cmd env microk8s status --format yaml |grep -i running: | sed "s/running://g" | tr -d '[:blank:]')
    [ ${isRunning} == "True" ]
}
################# check if kubernetes is running ##########
isK8sRunning() {
    elevate_cmd env kubectl cluster-info 2>&1 >/dev/null
    rc=$?
    return ${rc}
}
################# show shell script ###########
show_evals() {
#Inner functions
function kubectl() {
    sudo env microk8s kubectl $@
}
function helm() {
    sudo env microk8s helm $@
}

check_snap_alias kubectl
if [ $? != 0 ]; then
    _kubectl=$( declare -f kubectl)
else
    _kubectl=""
fi
check_snap_alias helm
if [ $? != 0 ]; then
   _helm=$( declare -f helm )
else
    _helm=""
fi

cat << EOF_EVALS
export KUBECONFIG=\${HOME}/.kube/_dpinstall_.yaml
$_kubectl
$_helm
EOF_EVALS
}
################# checksnap Alias ####################
check_snap_alias() {
    elevate_cmd env snap aliases | grep "${1}" 2>&1 >/dev/null
    return $?
}
################# create snap alias ###############
create_snap_alias() {
    elevate_cmd env snap aliases | grep "${1}" 2>&1 >/dev/null
    if [ $? == 0 ]; then
        elevate_cmd env snap unalias ${1} 2>&1 >/dev/null
    fi
    elevate_cmd env snap alias microk8s.${1} ${1}
}
################## ensure hostpath-storage #############
ensureHostPathStorage() {
    echo "[INFO] Checking hostpath-storage addon status."
    result=$(elevate_cmd env microk8s status -a hostpath-storage)
    if [ ${result} != "enabled" ]; then
        elevate_cmd env microk8s enable hostpath-storage
        result=$(elevate_cmd env microk8s status -a hostpath-storage)
        echo "[INFO] Checking hostpath-storage addon status:${result}"
    fi
}
##################### change autodetection ############
changeAutoDetection() {
    elevate_cmd sed -re "s/(value: \"first-found\")/value: \"interface=eth0\"/" -i /var/snap/microk8s/current/args/cni-network/cni.yaml
    elevate_cmd env kubectl apply -f /var/snap/microk8s/current/args/cni-network/cni.yaml
}
##################### replace server host ip ###########
changeHostIp() {
    bind_address=$(getIPAddress 1)
    for f in /var/snap/microk8s/current/credentials/*.config ; do
       sudo sed -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/"${bind_address}"/ -i $f
    done
}
################## start microk8s ###################
start_microk8s() {
    elevate_cmd env microk8s status --wait-ready

    isMicrok8sRunning
    if [ $? != 0 ]; then
        echo "[INFO] Starting microk8s..."
        elevate_cmd env microk8s start
    fi

    ensureHostPathStorage
    generateMicroK8sKubeConfig
    eval "export KUBECONFIG=${DPCLI_KUBECONFIG}"
    create_snap_alias kubectl
    create_snap_alias helm
    echo "Add the lines between BEGIN-END lines to your \${HOME}/.profile or startup script."
    echo "-------------------------- BEGIN ------------------------------------"
    show_evals
    echo "-------------------------- END --------------------------------------"


}
################## get storage class name ###########
getStorageClassName() {
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl get storageclass -o yaml | grep " name:"|  sed "s/name://g" | tr -d '[:blank:]'
}
################### get K8s IP Address #######
getIPAddress() {
    # SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd kubectl cluster-info | grep CoreDNS | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    hostname -I | awk -v num=$1 '{ print $num; }'
}
#################### get ingress class name ##############
getIngressClassName() {
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl get ingressclass -o yaml | grep " name:"|  sed "s/name://g" | tr -d '[:blank:]'
}
#################### get gateway object name ##############
getGatewayName() {
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl get gateway -A -o yaml 2>/dev/null | grep " name:"|  sed "s/name://g" | tr -d '[:blank:]'
}
############################# generate DP #########################
generateDP() {
    # Load default config
    dataplane_config=${1:-"${PWD}/dpregister.env"}
    echo "[INFO] Loading dataplane config : ${dataplane_config}"
    if [ -r "${dataplane_config}" ]; then
        source "${dataplane_config}"
        echo "\$HELM_REPO=${HELM_REPO}"
        echo "\$NS_CREATE=${NS_CREATE}"
        echo "\$SA_CREATE=${SA_CREATE}"
        echo "\$REG_COMMAND=${REG_COMMAND}"
        echo "\$INGRESS_CLASS_NAME=${INGRESS_CLASS_NAME}"

    dataplane_id=$(echo ${NS_CREATE}| sed -n "s/.*dataplane-id:\([a-z0-9]+\)*/\1/p" | awk '{ print $1; }')
    namespace=$(echo ${NS_CREATE}| sed -n "s/.*name:\([a-z0-9]+\)*/\1/p" | awk '{ print $1; }')
    echo "[INFO] Generating Dataplane script: reg_${namespace}_${dataplane_id}.sh"
    cat <<EOF_DP > "${PWD}/reg_${namespace}_${dataplane_id}.sh"
#!/usr/bin/env bash

echo "[INFO] Registering Dataplane Id: ${dataplane_id} on namespace: ${namespace}"
set -x
kubectl delete all --namespace ${namespace} --all
set +x
sleep 2
set -x
${HELM_REPO}
sleep 2
set -x
${NS_CREATE}
set +x
sleep 5
set -x
${SA_CREATE}
set +x
sleep 5
set -x
${REG_COMMAND}
set +x
echo "[INFO] Registration completed."
EOF_DP
     chmod +x ${PWD}/reg_${namespace}_${dataplane_id}.sh
     export DATAPLANE_SCRIPT="${PWD}/reg_${namespace}_${dataplane_id}.sh"
     echo "[INFO] Generated Dataplane script: reg_${namespace}_${dataplane_id}.sh succesfully."
     return 0
   fi
   echo "[ERROR] Dataplane config file: ${dataplane_config} not found."
   return 1
}

########################### load config #############################
loadDPConfig() {
    local dataplane_config=${1:-"${PWD}/dpregister.env"}
    echo "[INFO] Loading dataplane config : ${dataplane_config}"
    unset HELM_REPO
    unset NS_CREATE
    unset SA_CREATE
    unset REG_COMMAND
    unset INGRESS_CLASS_NAME
    unset INGRESS_CONTROLLER
    unset GATEWAY_NAME
    # unset INGRESS_CLASS_NAME
    if [ -r ${dataplane_config} ]; then
        source "${dataplane_config}"
        echo "\$HELM_REPO=${HELM_REPO}"
        echo "\$NS_CREATE=${NS_CREATE}"
        echo "\$SA_CREATE=${SA_CREATE}"
        echo "\$REG_COMMAND=${REG_COMMAND}"
        echo "\$INGRESS_CLASS_NAME=${INGRESS_CLASS_NAME}"
        echo "\$INGRESS_CONTROLLER=${INGRESS_CONTROLLER}"
        echo "\$GATEWAY_NAME=${GATEWAY_NAME}"
        dataplane_id=$(echo ${NS_CREATE}| sed -n "s/.*dataplane-id:\([a-z0-9]+\)*/\1/p" | awk '{ print $1; }')
        namespace=$(echo ${NS_CREATE}| sed -n "s/.*name:\([a-z0-9]+\)*/\1/p" | awk '{ print $1; }')
        export HELM_REPO
        export NS_CREATE
        export SA_CREATE
        export REG_COMMAND
        export INGRESS_CLASS_NAME
        export INGRESS_CONTROLLER
        export GATEWAY_NAME
        return 0
    fi


    echo "[ERROR] Dataplane config file: ${dataplane_config} not found."
    return 1

}

########################### registr DP ###############################
registerDP() {
    # set -x
    dataplane_script=${1}
    if [ -f "${dataplane_script}" ]; then
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd chmod +x "${dataplane_script}"
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env bash -c  "${dataplane_script}"
    else
        echo "[ERROR] Dataplane script not found at: ${dataplane_script}"
    fi
}
##################### get Kubernetes FQDN   ############
getFQDN() {
    echo "#################################################################################################"
    echo "[INFO] Please note down the name of the Ingress Controller class name my-nginx-ingress"
    echo "[INFO] Make sure a host name is assigned to the MACHINE_IP:${MACHINE_IP} or create a DNS record"
    echo "[INFO] for the IP, you will need the host name set as the FQDN name during the provisioning wizard"
    echo "[INFO] of the Bare Metal Data Plane on TIBCO Platform"
    echo "[INFO] If you entered FQDN name as \"myhost1234.example.com\" then create an entry in the"
    echo "[INFO] /etc/hosts file e.g."
    echo "[INFO]"
    echo "[INFO] ${MACHINE_IP}    myhost1234.example.com"
    echo "#################################################################################################"
    read -r -p "Please confirm DNS or /etc/hosts entry exists. Proceed (Y/N)" _opt
    case ${_opt} in
    [yY][eE][sS]|[yY])
        return 0
        ;;
    "*")
        return 1
        ;;
    esac
}
##################### install nginx ingress ###########
installIngressNginx() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
    if [ "$mode" != "silent" ];then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    # getFQDN
    if [ $? == 0 ]; then
        INGRESS_NS=ingress
        INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-nginx}"
        echo "[INFO] Using Kubernetes IP Address for ingress: ${MACHINE_IP}"
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --set controller.ingressClassResource.name=${INGRESS_CLASS_NAME} \
        --set "controller.service.externalIPs[0]=${MACHINE_IP}" \
        --namespace ${INGRESS_NS} \
        --create-namespace  > /dev/null 2>&1
        # SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd kubectl get service --namespace ingress ingress-nginx-controller --watch
        # SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd kubectl get ingressclass
        echo "[INFO] Nginx Ingress Class: ${INGRESS_CLASS_NAME} was installed"
    else
        echo "[INFO] Nginx Ingress Class: ${INGRESS_CLASS_NAME} was not installed"
    fi
}

##################### install traefik ingress ###########
installIngressTraefik() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add traefik https://traefik.github.io/charts
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
    if [ "$mode" != "silent" ];then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        INGRESS_NS=ingress
        INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-traefik}"
        echo "[INFO] Using Kubernetes IP Address for ingress: ${MACHINE_IP}"
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install traefik traefik/traefik \
        --set ingressClass.enabled=true \
        --set ingressClass.isDefaultClass=false \
        --set ingressClass.name=${INGRESS_CLASS_NAME} \
        --set "service.spec.externalIPs[0]=${MACHINE_IP}" \
        --namespace ${INGRESS_NS} \
        --create-namespace > /dev/null 2>&1
        echo "[INFO] Traefik Ingress Class: ${INGRESS_CLASS_NAME} was installed"
    else
        echo "[INFO] Traefik Ingress Class: ${INGRESS_CLASS_NAME} was not installed"
    fi
}

##################### install haproxy ingress ###########
installIngressHAProxy() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add haproxy https://haproxytech.github.io/helm-charts
    SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
    if [ "$mode" != "silent" ];then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        INGRESS_NS=ingress
        INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-haproxy}"
        echo "[INFO] Using Kubernetes IP Address for ingress: ${MACHINE_IP}"
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install haproxy-ingress haproxy/kubernetes-ingress \
        --set controller.ingressClassResource.name=${INGRESS_CLASS_NAME} \
        --set controller.ingressClassResource.isDefaultClass=false \
        --set controller.service.type=LoadBalancer \
        --set "controller.service.externalIPs[0]=${MACHINE_IP}" \
        --namespace ${INGRESS_NS} \
        --create-namespace > /dev/null 2>&1
        echo "[INFO] HAProxy Ingress Class: ${INGRESS_CLASS_NAME} was installed"
    else
        echo "[INFO] HAProxy Ingress Class: ${INGRESS_CLASS_NAME} was not installed"
    fi
}

##################### install nginx gateway fabric ###########
installNginxGatewayFabric() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    if [ "$mode" != "silent" ] && [ -z "$ip_address" ]; then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        GATEWAY_NS=nginx-gateway
        GATEWAY_NAME="${GATEWAY_NAME:-nginx-gateway}"
        echo "[INFO] Using Kubernetes IP Address for gateway: ${MACHINE_IP}"
        echo "[INFO] Installing Gateway API CRDs..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml > /dev/null 2>&1
        echo "[INFO] Installing NGINX Gateway Fabric..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install nginx-gateway-fabric oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
        --namespace ${GATEWAY_NS} \
        --create-namespace > /dev/null 2>&1
        echo "[INFO] Creating Gateway resource with external IP..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NS}
spec:
  gatewayClassName: nginx
  addresses:
  - type: IPAddress
    value: ${MACHINE_IP}
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
EOF
        echo "[INFO] NGINX Gateway Fabric GatewayClass: nginx and Gateway: ${GATEWAY_NAME} were installed"
    else
        echo "[INFO] NGINX Gateway Fabric GatewayClass: nginx was not installed"
    fi
}

##################### install traefik gateway controller ###########
installTraefikGatewayController() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    if [ "$mode" != "silent" ] && [ -z "$ip_address" ]; then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        GATEWAY_NS=traefik-gateway
        GATEWAY_NAME="${GATEWAY_NAME:-traefik-gateway}"
        echo "[INFO] Using Kubernetes IP Address for gateway: ${MACHINE_IP}"
        echo "[INFO] Installing Gateway API CRDs..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml > /dev/null 2>&1
        echo "[INFO] Installing Traefik Gateway Controller..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add traefik https://traefik.github.io/charts
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install traefik-gateway traefik/traefik \
        --namespace ${GATEWAY_NS} \
        --create-namespace \
        --set providers.kubernetesGateway.enabled=true \
        --set gateway.enabled=false \
        --set ingressClass.enabled=false \
        --set service.spec.externalIPs[0]="${MACHINE_IP}" \
        --set providers.kubernetesGateway.statusAddress.ip=${MACHINE_IP} > /dev/null 2>&1

        echo "[INFO] Creating Gateway resource with external IP..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NS}
spec:
  gatewayClassName: traefik
  addresses:
  - type: IPAddress
    value: ${MACHINE_IP}
  listeners:
  - name: http
    # LOGIC: We use port 8000 here because it matches the default Traefik
    # 'web' EntryPoint inside the pod. Traffic hits the VM on port 80,
    # and the K8s Service forwards it to this 8000 listener.
    port: 8000
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
EOF
        echo "[INFO] Traefik Gateway Controller GatewayClass: traefik and Gateway: ${GATEWAY_NAME} were installed"
    else
        echo "[INFO] Traefik Gateway Controller GatewayClass: traefik was not installed"
    fi
}

##################### install istio gateway controller ###########
installIstioGatewayController() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    if [ "$mode" != "silent" ] && [ -z "$ip_address" ]; then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        GATEWAY_NS=istio-gateway
        GATEWAY_NAME="${GATEWAY_NAME:-istio-gateway}"
        echo "[INFO] Using Kubernetes IP Address for gateway: ${MACHINE_IP}"
        echo "[INFO] Installing Gateway API CRDs..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml > /dev/null 2>&1
        echo "[INFO] Installing Istio Gateway Controller..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add istio https://istio-release.storage.googleapis.com/charts
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install istio-base istio/base \
        --namespace istio-system \
        --create-namespace \
        --wait \
        --timeout=1h > /dev/null 2>&1
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install istiod istio/istiod \
        --namespace istio-system \
        --wait \
        --timeout=1h > /dev/null 2>&1

        echo "[INFO] Creating istio-gateway namespace..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl create namespace ${GATEWAY_NS} > /dev/null 2>&1

        echo "[INFO] Creating Gateway resource with external IP..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NS}
spec:
  gatewayClassName: istio
  addresses:
  - type: IPAddress
    value: ${MACHINE_IP}
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
EOF

        echo "[INFO] Waiting for Gateway service to be created..."
        sleep 10

        echo "[INFO] Patching Gateway service to use external IP..."
        # Get the actual service name (pattern: gatewayname-istio)
        local istio_service=$(kubectl get svc -n ${GATEWAY_NS} -o name 2>/dev/null | grep "${GATEWAY_NAME}-istio" | head -1 || echo "")
        if [ ! -z "$istio_service" ]; then
            SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl patch $istio_service -n ${GATEWAY_NS} -p '{"spec":{"externalIPs":["'${MACHINE_IP}'"]}}'
        else
            echo "[WARN] Could not find Istio gateway service to patch. Service may remain in pending state."
        fi

        echo "[INFO] Istio Gateway Controller GatewayClass: istio and Gateway: ${GATEWAY_NAME} were installed"
    else
        echo "[INFO] Istio Gateway Controller GatewayClass: istio was not installed"
    fi
}

##################### install netscaler cpx gateway controller ###########
installNetScalerGatewayController() {
    local mode=${1:-"interactive"}
    local ip_address=${2}

    if [ "$mode" != "silent" ] && [ -z "$ip_address" ]; then
        echo "[INFO] Choose IP address:"
        num=1
        for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        MACHINE_IP=$(getIPAddress $_opt)
    else
        if [ -z "$ip_address" ];then
            MACHINE_IP=$(getIPAddress 1)
        else
            MACHINE_IP=$ip_address
        fi
    fi

    if [ $? == 0 ]; then
        GATEWAY_NS=netscaler-cpx-gateway
        GATEWAY_NAME="${GATEWAY_NAME:-netscaler-gateway}"
        TP_NETSCALER_ENTITY_PREFIX="${TP_NETSCALER_ENTITY_PREFIX:-gwy}"
        TP_NETSCALER_GATEWAY_CONTROLLER_NAME="${TP_NETSCALER_GATEWAY_CONTROLLER_NAME:-citrix.com/nscpxgw-controller}"
        echo "[INFO] Using Kubernetes IP Address for gateway: ${MACHINE_IP}"
        echo "[INFO] Installing Gateway API CRDs..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml > /dev/null 2>&1
        echo "[INFO] Installing NetScaler CPX Gateway Controller..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo add netscaler https://netscaler.github.io/netscaler-helm-charts/
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm repo update
        echo "[INFO] Creating namespace ${GATEWAY_NS}..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl create namespace ${GATEWAY_NS} || true
        
        echo "[INFO] Installing NetScaler CPX Gateway Controller Helm chart..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env helm upgrade --install cpx-gateway-controller netscaler/netscaler-cpx-with-gateway-controller \
        --namespace ${GATEWAY_NS} \
        --set license.accept=yes \
        --set gatewayController.entityPrefix="${TP_NETSCALER_ENTITY_PREFIX}" \
        --set gatewayController.gatewayControllerName="${TP_NETSCALER_GATEWAY_CONTROLLER_NAME}" \
        --set netscalerCpx.resources.requests.cpu=250m \
        --set netscalerCpx.resources.requests.memory=512Mi \
        --set netscalerCpx.resources.limits.cpu=1 \
        --set netscalerCpx.resources.limits.memory=1Gi \
        --set netscalerCpx.service.type=LoadBalancer \
        --set netscalerCpx.service.spec.externalIPs[0]="${MACHINE_IP}" \
        --set netscalerCpx.service.ports[0].port=80 \
        --set netscalerCpx.service.ports[0].targetPort=80 \
        --set netscalerCpx.service.ports[0].protocol=TCP \
        --set netscalerCpx.service.ports[0].name=http \
        --set netscalerCpx.service.ports[1].port=443 \
        --set netscalerCpx.service.ports[1].targetPort=443 \
        --set netscalerCpx.service.ports[1].protocol=TCP \
        --set netscalerCpx.service.ports[1].name=https
        
        if [ $? -ne 0 ]; then
            echo "[ERROR] Failed to install NetScaler CPX Gateway Controller Helm chart"
            return 1
        fi

        echo "[INFO] Creating GatewayClass for NetScaler..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: netscaler-gateway-class
spec:
  controllerName: ${TP_NETSCALER_GATEWAY_CONTROLLER_NAME}
EOF

        echo "[INFO] Waiting for GatewayClass to be accepted..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl wait --timeout=2m gatewayclass/netscaler-gateway-class --for=condition=Accepted

        echo "[INFO] Creating Gateway resource with external IP..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NS}
spec:
  gatewayClassName: netscaler-gateway-class
  addresses:
  - type: IPAddress
    value: ${MACHINE_IP}
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
EOF

        echo "[INFO] Waiting for Gateway to be programmed..."
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl wait --timeout=5m -n ${GATEWAY_NS} gateway/${GATEWAY_NAME} --for=condition=Programmed
        echo "[INFO] NetScaler CPX Gateway Controller GatewayClass: netscaler-gateway-class and Gateway: ${GATEWAY_NAME} were installed"
    else
        echo "[INFO] NetScaler CPX Gateway Controller GatewayClass: netscaler-gateway-class was not installed"
    fi
}

#################### init sudo #######################
init_sudo() {
    sudo -k
}
###################### installMicroK8s ########################
installMicroK8s() {
    init_sudo

    exit_root_user

    checkLinux

    if [ $? == 0 ]; then

        echo "[INFO] OS - Linux found"
        checkSnapExists
        [ $? != 0 ] && echo "[ERROR] Snap package manager is not installed" && exit 1
        echo "[INFO] Snap package manager found"
        # showClusterInfo
        checkMicroK8sExists
        if [ $? != 0 ]; then
            echo "[INFO] microk8s is not installed"
            MICRO_K8S_INSTALLED=false
        fi

        if [ "${MICRO_K8S_INSTALLED}" == false ]; then
            echo "################################################################################"
            echo "PLEASE NOTE: If you are running docker-desktop on WSL and have a high CPU/Memory"
            echo "being used for running large number of containers e.g. Kubernetes Cluster then"
            echo "Please stop and close the docker-desktop windows application before proceeding"
            echo "further. You can start docker-desktop after MicroK8s installation on WSL Linux"
            echo "is complete"
            echo "################################################################################"
            read -r -p "Do you want to proceed with microK8s installation? (Y/N)" _opt
            case ${_opt} in
            [yY][eE][sS]|[yY])
                install_microk8s
                set_microk8s_permissions
                start_microk8s
                echo "################################################################################"
                echo "kubectl get nodes"
                elevate_cmd env kubectl get nodes
                echo "kubectl cluster-info"
                elevate_cmd env kubectl cluster-info
                echo "Helm version"
                elevate_cmd env helm version
                echo "################################################################################"
                ;;
            "*")
                ;;
            esac

        else
            read -r -p "Do you want to uninstall the previous installation of microK8s?(Y/N)" _opt
            case ${_opt} in
            [yY][eE][sS]|[yY])
                uninstall_microk8s
                ;;
            "*")
                ;;
            esac
        fi
    else
    echo "OS - Linux not found"
    exit 1
    fi
}
################### install microk8s silent ############################
installMicroK8s__silent() {
    init_sudo

    exit_root_user


    checkLinux

    if [ $? == 0 ]; then

        echo "[INFO] OS - Linux found"
        checkSnapExists
        [ $? != 0 ] && echo "[ERROR] Snap package manager is not installed" && exit 1
        echo "[INFO] Snap package manager found"
        # showClusterInfo
        checkMicroK8sExists
        if [ $? != 0 ]; then
            echo "[INFO] microk8s is not installed"
            MICRO_K8S_INSTALLED=false
        fi

        if [ "${MICRO_K8S_INSTALLED}" == false ]; then
            install_microk8s
            set_microk8s_permissions
            start_microk8s
            echo "################################################################################"
            echo "kubectl get nodes"
            elevate_cmd env kubectl get nodes
            echo "kubectl cluster-info"
            elevate_cmd env kubectl cluster-info
            echo "Helm version"
            elevate_cmd env helm version
            echo "################################################################################"

        else
            echo "[INFO] MicroK8s is already installed"
        fi
    else
    echo "OS - Linux not found"
    exit 1
    fi
}
##################### Deploy Data Plane ###############
deployDataPlane() {
    local o_kubectl=kubectl
    local o_helm=helm
    checkPrerequisites() {
        # unset -f kubectl
        # unset -f helm
        echo "[INFO] Checking prerequisites..."
        checkKubeCtlExists
        [ $? != 0 ] && echo "[ERROR] kubectl command not found." && return 1
        echo "[INFO] Check kubectl ...found"

        checkHelmExists
        [ $? != 0 ] && echo "[ERROR] helm command not found." && return 1
        echo "[INFO] Check helm ...found"

        checkKubeConfig
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check KUBECONFIG ...found ${KUBECONFIG}"

        SUDO_ENV=${SUDO_ENV_VARS} isK8sRunning
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check kubernetes ... running"
        ensureHostPathStorage
        return 0
    }
    #Inner functions
    function _kubectl() {
        sudo env microk8s kubectl $@
    }
    function _helm() {
        sudo env microk8s helm $@
    }



    checkPrerequisites
    if [ $? != 0 ]; then
        checkMicroK8sExists
        if [ $? == 0 ]; then
            echo "[INFO] microk8s is installed"
            read -r -p "Do you want to use microK8s kubectl and helm commands (Y/N)" _opt
            case ${_opt} in
            [yY][eE][sS]|[yY])
                # source <(show_evals)
                check_snap_alias kubectl
                if [ $? != 0 ]; then
                    echo "[INFO] Setting microk8s kubectl function"
                    kubectl=_kubectl
                    unsetFunctions=1
                fi
                check_snap_alias helm
                if [ $? != 0 ]; then
                    echo "[INFO] Setting microk8s helm function"
                    helm=_helm
                    unsetFunctions=1
                fi

                ;;
            "*")
                ;;
            esac
        fi
    fi
    loadDPConfig ${DATAPLANE_CONFIG}
    [ $? != 0 ] && return 1
    echo "[INFO] Generating data plane script ..."
    elevate_cmd env kubectl cluster-info
    elevate_cmd env helm version

    echo "[INFO] StorageClass: $(getStorageClassName)"
    ### interactive prompt to install the specific ingress controller based on INGRESS_CONTROLLER
    selected_ic=$(echo "${INGRESS_CONTROLLER}" | tr '[:upper:]' '[:lower:]')
    case "${selected_ic}" in
    nginx)
        read -r -p "Do you want to install Nginx Ingress Controller? (Y/N) " _opt
        case ${_opt} in
            [yY][eE][sS]|[yY])
                echo "[INFO] Installing Nginx Ingress Controller (interactive)"
                installIngressNginx
                echo "[INFO] IngressClass: $(getIngressClassName)"
                ;;
            *) ;;
        esac
        ;;
    traefik)
        read -r -p "Do you want to install Traefik Ingress Controller? (Y/N) " _opt
        case ${_opt} in
            [yY][eE][sS]|[yY])
                echo "[INFO] Installing Traefik Ingress Controller (interactive)"
                installIngressTraefik
                echo "[INFO] IngressClass: $(getIngressClassName)"
                ;;
            *) ;;
        esac
        ;;
    haproxy)
        read -r -p "Do you want to install HAProxy Ingress Controller? (Y/N) " _opt
        case ${_opt} in
            [yY][eE][sS]|[yY])
                echo "[INFO] Installing HAProxy Ingress Controller (interactive)"
                installIngressHAProxy
                echo "[INFO] IngressClass: $(getIngressClassName)"
                ;;
            *) ;;
        esac
        ;;
    ""|*)
        echo "[INFO] INGRESS_CONTROLLER not set or unsupported. Skipping ingress controller installation."
        ;;
    esac

    # Gateway Controller installation based on GATEWAY_CONTROLLER
    if [ ! -z "${GATEWAY_CONTROLLER}" ] && [ "${GATEWAY_CONTROLLER}" != "" ]; then
        selected_gc=$(echo "${GATEWAY_CONTROLLER}" | tr '[:upper:]' '[:lower:]')
        case "${selected_gc}" in
        nginx-gateway-fabric|ngf)
            read -r -p "Do you want to install NGINX Gateway Fabric Controller? (Y/N) " _opt
            case ${_opt} in
                [yY][eE][sS]|[yY])
                    echo "[INFO] Installing NGINX Gateway Fabric Controller (interactive)"
                    installNginxGatewayFabric
                    echo "[INFO] Gateway: $(getGatewayName)"
                    ;;
                *) ;;
            esac
            ;;
        traefik-gateway)
            read -r -p "Do you want to install Traefik Gateway Controller? (Y/N) " _opt
            case ${_opt} in
                [yY][eE][sS]|[yY])
                    echo "[INFO] Installing Traefik Gateway Controller (interactive)"
                    installTraefikGatewayController
                    echo "[INFO] Gateway: $(getGatewayName)"
                    ;;
                *) ;;
            esac
            ;;
        istio-gateway)
            read -r -p "Do you want to install Istio Gateway Controller? (Y/N) " _opt
            case ${_opt} in
                [yY][eE][sS]|[yY])
                    echo "[INFO] Installing Istio Gateway Controller (interactive)"
                    installIstioGatewayController
                    echo "[INFO] Gateway: $(getGatewayName)"
                    ;;
                *) ;;
            esac
            ;;
        netscaler-gateway|netscaler-cpx)
            read -r -p "Do you want to install NetScaler CPX Gateway Controller? (Y/N) " _opt
            case ${_opt} in
                [yY][eE][sS]|[yY])
                    echo "[INFO] Installing NetScaler CPX Gateway Controller (interactive)"
                    installNetScalerGatewayController
                    echo "[INFO] Gateway: $(getGatewayName)"
                    ;;
                *) ;;
            esac
            ;;
        ""|*)
            echo "[INFO] GATEWAY_CONTROLLER not set or unsupported. Skipping gateway controller installation."
            ;;
        esac
    fi

    generateDP ${DATAPLANE_CONFIG}
    if [ $? == 0 ]; then
        dp_script=${DATAPLANE_SCRIPT}
        registerDP ${dp_script}
    else
        echo "[ERROR] Failed to generate dataplane script and register"
    fi

    ## cleanup
    if [ "${unsetFunctions}" == "1" ]; then
        echo "[INFO] Removing microk8s kubectl & helm functions"
        kubectl=o_kubectl
        helm=o_helm
        # unset -f kubectl
        # unset -f helm
    fi

}
###################### Deploye Data Plane Silent ##################
deployDataPlane__silent() {
    local o_kubectl=kubectl
    local o_helm=helm
    checkPrerequisites() {
        # unset -f kubectl
        # unset -f helm
        echo "[INFO] Checking prerequisites..."
        checkKubeCtlExists
        [ $? != 0 ] && echo "[ERROR] kubectl command not found." && return 1
        echo "[INFO] Check kubectl ...found"

        checkHelmExists
        [ $? != 0 ] && echo "[ERROR] helm command not found." && return 1
        echo "[INFO] Check helm ...found"

        checkKubeConfig
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check KUBECONFIG ...found ${KUBECONFIG}"

        SUDO_ENV=${SUDO_ENV_VARS} isK8sRunning
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check kubernetes ... running"
        ensureHostPathStorage
        return 0
    }
    #Inner functions
    function _kubectl() {
        sudo env microk8s kubectl $@
    }
    function _helm() {
        sudo env microk8s helm $@
    }



    checkPrerequisites
    if [ $? != 0 ]; then
        checkMicroK8sExists
        if [ $? == 0 ]; then
            echo "[INFO] microk8s is installed"
            # source <(show_evals)
                check_snap_alias kubectl
                if [ $? != 0 ]; then
                    echo "[INFO] Setting microk8s kubectl function"
                    kubectl=_kubectl
                    unsetFunctions=1
                fi
                check_snap_alias helm
                if [ $? != 0 ]; then
                    echo "[INFO] Setting microk8s helm function"
                    helm=_helm
                    unsetFunctions=1
                fi
        fi
    fi

    loadDPConfig ${DATAPLANE_CONFIG}
    [ $? != 0 ] && return 1
    echo "[INFO] Deploy data plane ..."
    elevate_cmd env kubectl cluster-info
    elevate_cmd env helm version

    echo "[INFO] StorageClass: $(getStorageClassName)"
    if [ "${SKIP_NGINX_CONTROLLER}" != "true" ]; then
        ingress_ip_address=${1}
        if [ -z "${ingress_ip_address}" ]; then
            echo "[WARN] Ingress IPV4 Address not specified, using \$(hostname -I)[0]"
            ingress_ip_address=$(getIPAddress 1)
        fi
        case "${INGRESS_CONTROLLER}" in
        nginx)
            echo "[INFO] Installing Nginx Ingress Controller (silent) as specified by INGRESS_CONTROLLER=${INGRESS_CONTROLLER}"
            installIngressNginx silent ${ingress_ip_address}
            echo "[INFO] IngressClass: $(getIngressClassName)"
            ;;
        traefik)
            echo "[INFO] Installing Traefik Ingress Controller (silent) as specified by INGRESS_CONTROLLER=${INGRESS_CONTROLLER}"
            installIngressTraefik silent ${ingress_ip_address}
            echo "[INFO] IngressClass: $(getIngressClassName)"
            ;;
        haproxy)
            echo "[INFO] Installing HAProxy Ingress Controller (silent) as specified by INGRESS_CONTROLLER=${INGRESS_CONTROLLER}"
            installIngressHAProxy silent ${ingress_ip_address}
            echo "[INFO] IngressClass: $(getIngressClassName)"
            ;;
        ""|*)
            echo "[INFO] INGRESS_CONTROLLER not set or unsupported. Skipping ingress controller installation."
            ;;
        esac
    fi

    # Gateway Controller installation based on GATEWAY_CONTROLLER
    if [ ! -z "${GATEWAY_CONTROLLER}" ] && [ "${GATEWAY_CONTROLLER}" != "" ]; then
        gateway_ip_address=${1}
        if [ -z "${gateway_ip_address}" ]; then
            echo "[WARN] Gateway IPV4 Address not specified, using \$(hostname -I)[0]"
            gateway_ip_address=$(getIPAddress 1)
        fi
        case "${GATEWAY_CONTROLLER}" in
        nginx-gateway-fabric|ngf)
            echo "[INFO] Installing NGINX Gateway Fabric Controller (silent) as specified by GATEWAY_CONTROLLER=${GATEWAY_CONTROLLER}"
            installNginxGatewayFabric silent ${gateway_ip_address}
            echo "[INFO] Gateway: $(getGatewayName)"
            ;;
        traefik-gateway)
            echo "[INFO] Installing Traefik Gateway Controller (silent) as specified by GATEWAY_CONTROLLER=${GATEWAY_CONTROLLER}"
            installTraefikGatewayController silent ${gateway_ip_address}
            echo "[INFO] Gateway: $(getGatewayName)"
            ;;
        istio-gateway)
            echo "[INFO] Installing Istio Gateway Controller (silent) as specified by GATEWAY_CONTROLLER=${GATEWAY_CONTROLLER}"
            installIstioGatewayController silent ${gateway_ip_address}
            echo "[INFO] Gateway: $(getGatewayName)"
            ;;
        netscaler-gateway|netscaler-cpx)
            echo "[INFO] Installing NetScaler CPX Gateway Controller (silent) as specified by GATEWAY_CONTROLLER=${GATEWAY_CONTROLLER}"
            installNetScalerGatewayController silent ${gateway_ip_address}
            echo "[INFO] Gateway: $(getGatewayName)"
            ;;
        ""|*)
            echo "[INFO] GATEWAY_CONTROLLER not set or unsupported. Skipping gateway controller installation."
            ;;
        esac
    fi

    generateDP ${DATAPLANE_CONFIG}

    if [ $? == 0 ]; then
        dp_script=${DATAPLANE_SCRIPT}
        registerDP ${dp_script}
    else
        echo "[ERROR] Failed to generate dataplane script and register"
    fi

    ## cleanup
    if [ "${unsetFunctions}" == "1" ]; then
        echo "[INFO] Removing microk8s kubectl & helm functions"
        kubectl=o_kubectl
        helm=o_helm
        # unset -f kubectl
        # unset -f helm
    fi

}
##################### show status #####################
showStatus() {
    checkPrerequisites() {
        # unset -f kubectl
        # unset -f helm
        # set -x
        echo "[INFO] Checking prerequisites..."
        checkKubeCtlExists
        [ $? != 0 ] && echo "[ERROR] kubectl command not found." && return 1
        echo "[INFO] Check kubectl ...found"

        checkHelmExists
        [ $? != 0 ] && echo "[ERROR] helm command not found." && return 1
        echo "[INFO] Check helm ...found"

        checkKubeConfig
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check KUBECONFIG ...found ${KUBECONFIG}"

        SUDO_ENV=${SUDO_ENV_VARS} isK8sRunning
        [ $? != 0 ] && echo "[ERROR] KUBECONFIG file not found." && return 1
        echo "[INFO] Check kubernetes ... running"
        ensureHostPathStorage
        return 0
    }
    checkPrerequisites
    if [ $? == 0 ]; then
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env microk8s config
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl cluster-info
        SUDO_ENV=${SUDO_ENV_VARS} elevate_cmd env kubectl get po -A
    fi
}

userChoiceK8s() {
    ## declare an array variable
    # declare -a k8schoices=("microk8s" "minikube")
    declare -a k8schoices=("microk8s")
    size=${#k8schoices[@]}
    if [ ${size} -gt  1 ]; then
        echo "Please choose Kubernetes Type:"
        num=1
        for i in "${k8schoices[@]}"; do
        echo "${num}) $i"
        num=$((num+1))
        done
        read -r -p "Enter the option number:   " _opt
        choice=$((${_opt}-1))
    else
        choice=0
    fi
    export K8S_TYPE=${k8schoices[${choice}]}
    echo "[INFO] Kubernetes Type: ${K8S_TYPE}"

}
###################### User Choices ###################
userChoices () {
  echo "Please choose any one of the below options:"
  echo -e "  1) Install Kubernetes - microk8s  \n  2) Uninstall Kubernetes - microk8s  \n  3) Register Data Plane \n  4) Manage Ingress / Gateway Controllers \n  5) Exit"
  # shellcheck disable=SC2162
  read -r -p "Enter the option number:   " _opt
  case ${_opt} in
    "1")
      userChoiceK8s
      echo "[INFO] Installing Kubernetes - ${K8S_TYPE}"
      case ${K8S_TYPE} in
        "microk8s")
            installMicroK8s $@
        ;;
        *)
        echo "[ERROR] Unsupported Kubernetes Type"
        ;;
      esac

    ;;
    "2")
        userChoiceK8s
        echo "[INFO] Uninstall Kubernetes - ${K8S_TYPE}"
        case ${K8S_TYPE} in
        "microk8s")
            uninstall_microk8s $@
        ;;
        *)
        echo "[ERROR] Unsupported Kubernetes Type"
        ;;
      esac

    ;;
    "3")
      echo "[INFO] Register Data Plane"
      deployDataPlane $@
    ;;
    "4")
      echo "[INFO] Manage Ingress / Gateway Controllers"
      manageControllers $@
    ;;
    "5")
      echo "=> Exit"
      exit 0
    ;;
     *)
     echo "[WARN] => invalid input. Expected either of 1,2,3,4 or 5"
    ;;
  esac
  userChoices
}
################## install k8s ######################3
installk8s__silent() {
    type=${K8S_TYPE:-"microk8s"}
    case ${type} in
    microk8s)
    installMicroK8s__silent
    ;;
    *)
    echo "[ERROR] Unsupported Kubernetes type"
    ;;
    esac
}

################## install k8s ######################3
removek8s__silent() {
    type=${K8S_TYPE:-"microk8s"}
    case ${type} in
    microk8s)
    uninstall_microk8s
    ;;
    *)
    echo "[ERROR] Unsupported Kubernetes type"
    ;;
    esac
}
################### run silent mode ##################
runSilentMode() {
    _opt=${1}
    # echo "RunSilentMode $@"
    case ${_opt} in
    install_k8s)
        installk8s__silent

    ;;
    remove_k8s)
        removek8s__silent
    ;;
    showStatus)
        showStatus
    ;;
    register_dp)
        deployDataPlane__silent  ${INGRESS_IP}
    ;;

    esac
}
###################### Manage Controllers ###################
manageControllers() {
    while true; do
        echo ""
        echo "Manage Ingress / Gateway Controllers:"
        echo "  1) Install New Controller"
        echo "  2) Uninstall Controller"
        echo "  3) List Installed Controllers"
        echo "  4) Back to main menu"
        read -r -p "Enter option number: " opt

        case $opt in
            1)
                installNewController
                ;;
            2)
                uninstallController
                ;;
            3)
                listInstalledControllers
                ;;
            4)
                break
                ;;
            *)
                echo "[WARN] Invalid option. Please enter 1, 2, 3, or 4"
                ;;
        esac
    done
}

installNewController() {
    echo ""
    echo "Select Controller Type:"
    echo "  1) Ingress Controller"
    echo "  2) Gateway Controller"
    echo "  3) Back"
    read -r -p "Enter option number: " type_opt

    case $type_opt in
        1)
            installIngressControllerMenu
            ;;
        2)
            installGatewayControllerMenu
            ;;
        3)
            return
            ;;
        *)
            echo "[WARN] Invalid option"
            return
            ;;
    esac
}

installIngressControllerMenu() {
    echo ""
    echo "Select Ingress Controller:"
    echo "  1) Nginx Ingress Controller"
    echo "  2) Traefik Ingress Controller"
    echo "  3) HAProxy Ingress Controller"
    echo "  4) Back"
    read -r -p "Enter option number: " ic_opt

    case $ic_opt in
        1)
            installIngressControllerInteractive "nginx-ingress"
            ;;
        2)
            installIngressControllerInteractive "traefik-ingress"
            ;;
        3)
            installIngressControllerInteractive "haproxy-ingress"
            ;;
        4)
            return
            ;;
        *)
            echo "[WARN] Invalid option"
            return
            ;;
    esac
}

installGatewayControllerMenu() {
    echo ""
    echo "Select Gateway Controller:"
    echo "  1) NGINX Gateway Fabric"
    echo "  2) Traefik Gateway Controller"
    echo "  3) Istio Gateway Controller"
    echo "  4) NetScaler CPX Gateway Controller"
    echo "  5) Back"
    read -r -p "Enter option number: " gc_opt

    case $gc_opt in
        1)
            installGatewayControllerInteractive "nginx-gateway-fabric"
            ;;
        2)
            installGatewayControllerInteractive "traefik-gateway"
            ;;
        3)
            installGatewayControllerInteractive "istio-gateway"
            ;;
        4)
            installGatewayControllerInteractive "netscaler-gateway"
            ;;
        5)
            return
            ;;
        *)
            echo "[WARN] Invalid option"
            return
            ;;
    esac
}

installIngressControllerInteractive() {
    local controller_type=$1

    # Set ingress class name (hardcoded for consistency with detection)
    if [ "$controller_type" = "nginx-ingress" ]; then
        ingress_class="nginx"
    elif [ "$controller_type" = "traefik-ingress" ]; then
        ingress_class="traefik"
    else
        ingress_class="haproxy"
    fi

    # Get IP address
    echo ""
    echo "Choose IP address:"
    num=1
    for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
    done
    read -r -p "Enter the option number:   " ip_opt

    local machine_ip=$(getIPAddress $ip_opt)

    if [ -z "$machine_ip" ]; then
        echo "[ERROR] Invalid IP address selection"
        return 1
    fi

    # Set environment variables BEFORE calling installation functions
    export INGRESS_CLASS_NAME="$ingress_class"
    export INGRESS_CONTROLLER="$controller_type"

    if [ "$controller_type" = "nginx-ingress" ]; then
        echo "[INFO] Installing Nginx Ingress Controller..."
        installIngressNginx "interactive" "$machine_ip"
    elif [ "$controller_type" = "traefik-ingress" ]; then
        echo "[INFO] Installing Traefik Ingress Controller..."
        installIngressTraefik "interactive" "$machine_ip"
    else
        echo "[INFO] Installing HAProxy Ingress Controller..."
        installIngressHAProxy "interactive" "$machine_ip"
    fi

    if [ $? -eq 0 ]; then
        echo "✓ $controller_type Ingress Controller installed successfully"
        echo "✓ IngressClass: $ingress_class created"
        echo "✓ Service IP: $machine_ip"
    else
        echo "[ERROR] Failed to install $controller_type Ingress Controller"
    fi
}

installGatewayControllerInteractive() {
    local controller_type=$1

    # Set gateway name based on controller type
    if [ "$controller_type" = "nginx-gateway-fabric" ]; then
        gateway_name="nginx-gateway"
    elif [ "$controller_type" = "traefik-gateway" ]; then
        gateway_name="traefik-gateway"
    elif [ "$controller_type" = "netscaler-gateway" ]; then
        gateway_name="netscaler-gateway"
    else
        gateway_name="istio-gateway"
    fi

    # Get IP address
    echo ""
    echo "Choose IP address:"
    num=1
    for i in $(hostname -I); do
        echo "${num}) $i"
        num=$((num+1))
    done
    read -r -p "Enter the option number:   " ip_opt

    local machine_ip=$(getIPAddress $ip_opt)

    if [ -z "$machine_ip" ]; then
        echo "[ERROR] Invalid IP address selection"
        return 1
    fi

    # Set environment variables and install
    export GATEWAY_NAME="$gateway_name"

    if [ "$controller_type" = "nginx-gateway-fabric" ]; then
        echo "[INFO] Installing NGINX Gateway Fabric..."
        installNginxGatewayFabric "interactive" "$machine_ip"

        if [ $? -eq 0 ]; then
            echo "✓ NGINX Gateway Fabric installed successfully"
            echo "✓ Gateway: $gateway_name created"
            echo "✓ Service IP: $machine_ip"
        else
            echo "[ERROR] Failed to install NGINX Gateway Fabric"
        fi
    elif [ "$controller_type" = "traefik-gateway" ]; then
        echo "[INFO] Installing Traefik Gateway Controller..."
        installTraefikGatewayController "interactive" "$machine_ip"

        if [ $? -eq 0 ]; then
            echo "✓ Traefik Gateway Controller installed successfully"
            echo "✓ Gateway: $gateway_name created"
            echo "✓ Service IP: $machine_ip"
        else
            echo "[ERROR] Failed to install Traefik Gateway Controller"
        fi
    elif [ "$controller_type" = "netscaler-gateway" ]; then
        echo "[INFO] Installing NetScaler CPX Gateway Controller..."
        installNetScalerGatewayController "interactive" "$machine_ip"

        if [ $? -eq 0 ]; then
            echo "✓ NetScaler CPX Gateway Controller installed successfully"
            echo "✓ Gateway: $gateway_name created"
            echo "✓ Service IP: $machine_ip"
        else
            echo "[ERROR] Failed to install NetScaler CPX Gateway Controller"
        fi
    else
        echo "[INFO] Installing Istio Gateway Controller..."
        installIstioGatewayController "interactive" "$machine_ip"

        if [ $? -eq 0 ]; then
            echo "✓ Istio Gateway Controller installed successfully"
            echo "✓ Gateway: $gateway_name created"
            echo "✓ Service IP: $machine_ip"
        else
            echo "[ERROR] Failed to install Istio Gateway Controller"
        fi
    fi
}

uninstallController() {
    echo ""
    echo "Uninstall Controller:"

    local controllers=()
    local count=0

    # Check for Nginx Ingress Controller (check for any nginx ingressclass)
    local nginx_class=$(kubectl get ingressclass -o name 2>/dev/null | grep nginx || echo "")
    if [ ! -z "$nginx_class" ]; then
        controllers[count]="nginx-ingress"
        echo "$((count+1))) Nginx Ingress Controller (ingressclass: $nginx_class)"
        count=$((count+1))
    fi

    # Check for Traefik Ingress Controller (exclude traefik-gateway ingressclass which is created by Gateway Controller)
    local traefik_class=$(kubectl get ingressclass -o name 2>/dev/null | grep traefik | grep -v "traefik-gateway" || echo "")
    if [ ! -z "$traefik_class" ]; then
        controllers[count]="traefik-ingress"
        echo "$((count+1))) Traefik Ingress Controller (ingressclass: $traefik_class)"
        count=$((count+1))
    fi

    # Check for HAProxy Ingress Controller
    local haproxy_class=$(kubectl get ingressclass -o name 2>/dev/null | grep haproxy || echo "")
    if [ ! -z "$haproxy_class" ]; then
        controllers[count]="haproxy-ingress"
        echo "$((count+1))) HAProxy Ingress Controller (ingressclass: $haproxy_class)"
        count=$((count+1))
    fi

    # Check for NGINX Gateway Fabric
    local gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep nginx || echo "")
    if [ ! -z "$gateway_class" ]; then
        controllers[count]="nginx-gateway-fabric"
        echo "$((count+1))) NGINX Gateway Fabric (gatewayclass: $gateway_class)"
        count=$((count+1))
    fi

    # Check for Traefik Gateway Controller
    local traefik_gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep traefik || echo "")
    if [ ! -z "$traefik_gateway_class" ]; then
        controllers[count]="traefik-gateway"
        echo "$((count+1))) Traefik Gateway Controller (gatewayclass: $traefik_gateway_class)"
        count=$((count+1))
    fi

    # Check for Istio Gateway Controller
    local istio_gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep istio || echo "")
    if [ ! -z "$istio_gateway_class" ]; then
        controllers[count]="istio-gateway"
        echo "$((count+1))) Istio Gateway Controller (gatewayclass: $istio_gateway_class)"
        count=$((count+1))
    fi

    # Check for NetScaler Gateway Controller
    local netscaler_gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep netscaler || echo "")
    if [ ! -z "$netscaler_gateway_class" ]; then
        controllers[count]="netscaler-gateway"
        echo "$((count+1))) NetScaler CPX Gateway Controller (gatewayclass: $netscaler_gateway_class)"
        count=$((count+1))
    fi

    if [ $count -eq 0 ]; then
        echo "No controllers installed by this script"
        echo "Note: Other LoadBalancer services may exist but cannot be uninstalled via this script"
        return
    fi

    echo "$((count+1))) Back"
    read -r -p "Enter option number: " opt

    if [ "$opt" = "$((count+1))" ]; then
        return
    fi

    if [ "$opt" -lt 1 ] || [ "$opt" -gt $count ]; then
        echo "[WARN] Invalid option"
        return
    fi

    local controller_type="${controllers[$((opt-1))]}"

    echo ""
    echo "⚠️  WARNING: This will remove $controller_type controller"
    echo "⚠️  Ensure applications have migrated to another controller"
    read -r -p "Continue uninstall? (Y/N): " confirm

    case $confirm in
        [yY][eE][sS]|[yY])
            uninstallSpecificController "$controller_type"
            ;;
        *)
            echo "[INFO] Uninstall cancelled"
            ;;
    esac
}

uninstallSpecificController() {
    local controller_type=$1

    case $controller_type in
        nginx-ingress)
            echo "[INFO] Uninstalling Nginx Ingress Controller..."
            helm uninstall ingress-nginx -n ingress 2>/dev/null || true
            # Find and delete any nginx ingressclass
            local nginx_class=$(kubectl get ingressclass -o name 2>/dev/null | grep nginx | head -1)
            if [ ! -z "$nginx_class" ]; then
                kubectl delete ingressclass "$nginx_class" 2>/dev/null || true
            fi
            echo "✓ Nginx Ingress Controller uninstalled"
            ;;
        traefik-ingress)
            echo "[INFO] Uninstalling Traefik Ingress Controller..."
            helm uninstall traefik -n ingress 2>/dev/null || true
            # Find and delete any traefik ingressclass
            local traefik_class=$(kubectl get ingressclass -o name 2>/dev/null | grep traefik | head -1)
            if [ ! -z "$traefik_class" ]; then
                kubectl delete ingressclass "$traefik_class" 2>/dev/null || true
            fi
            echo "✓ Traefik Ingress Controller uninstalled"
            ;;
        haproxy-ingress)
            echo "[INFO] Uninstalling HAProxy Ingress Controller..."
            helm uninstall haproxy-ingress -n ingress 2>/dev/null || true
            # Find and delete any haproxy ingressclass
            local haproxy_class=$(kubectl get ingressclass -o name 2>/dev/null | grep haproxy | head -1)
            if [ ! -z "$haproxy_class" ]; then
                kubectl delete ingressclass "$haproxy_class" 2>/dev/null || true
            fi
            echo "✓ HAProxy Ingress Controller uninstalled"
            ;;
        nginx-gateway-fabric)
            echo "[INFO] Uninstalling NGINX Gateway Fabric..."
            # Try to delete any gateway in nginx-gateway namespace
            kubectl delete gateway --all -n nginx-gateway 2>/dev/null || true
            helm uninstall nginx-gateway-fabric -n nginx-gateway 2>/dev/null || true
            kubectl delete gatewayclass nginx 2>/dev/null || true
            echo "✓ NGINX Gateway Fabric uninstalled"
            ;;
        traefik-gateway)
            echo "[INFO] Uninstalling Traefik Gateway Controller..."
            # Try to delete any gateway in traefik-gateway namespace
            kubectl delete gateway --all -n traefik-gateway 2>/dev/null || true
            helm uninstall traefik-gateway -n traefik-gateway 2>/dev/null || true
            kubectl delete gatewayclass traefik 2>/dev/null || true
            echo "✓ Traefik Gateway Controller uninstalled"
            ;;
        istio-gateway)
            echo "[INFO] Uninstalling Istio Gateway Controller..."
            # Try to delete any gateway in istio-gateway namespace
            kubectl delete gateway --all -n istio-gateway 2>/dev/null || true
            helm uninstall istio-base -n istio-system 2>/dev/null || true
            helm uninstall istiod -n istio-system 2>/dev/null || true
            kubectl delete namespace istio-gateway 2>/dev/null || true
            kubectl delete gatewayclass istio 2>/dev/null || true
            kubectl delete gatewayclass istio-remote 2>/dev/null || true
            echo "✓ Istio Gateway Controller uninstalled"
            ;;
        netscaler-gateway)
            echo "[INFO] Uninstalling NetScaler CPX Gateway Controller..."
            # Try to delete any gateway in ingress namespace
            kubectl delete gateway --all -n ingress 2>/dev/null || true
            helm uninstall cpx-gateway-controller -n ingress 2>/dev/null || true
            kubectl delete gatewayclass netscaler-gateway-class 2>/dev/null || true
            echo "✓ NetScaler CPX Gateway Controller uninstalled"
            ;;
        *)
            echo "[ERROR] Unknown controller type: $controller_type"
            return 1
            ;;
    esac
}

listInstalledControllers() {
    echo ""
    echo "Installed Controllers:"

    # Load config once at the beginning
    loadDPConfig ${DATAPLANE_CONFIG} > /dev/null 2>&1

    local found=false

    # Check for Nginx Ingress Controller (check for any nginx ingressclass)
    local nginx_class=$(kubectl get ingressclass -o name 2>/dev/null | grep nginx || echo "")
    if [ ! -z "$nginx_class" ]; then
        echo "✓ Nginx Ingress Controller"
        echo "  - Type: Ingress Controller"
        echo "  - IngressClass: $nginx_class"
        echo "  - Namespace: ingress"
        echo "  - Service: ingress-nginx-controller"
        echo ""
        found=true
    fi

    # Check Traefik Ingress Controller (exclude traefik-gateway ingressclass which is created by Gateway Controller)
    local traefik_class=$(kubectl get ingressclass -o name 2>/dev/null | grep traefik | grep -v "traefik-gateway" || echo "")
    if [ ! -z "$traefik_class" ]; then
        echo "✓ Traefik Ingress Controller"
        echo "  - Type: Ingress Controller"
        echo "  - IngressClass: $traefik_class"
        echo "  - Namespace: ingress"
        echo "  - Service: traefik"
        echo ""
        found=true
    fi

    # Check for HAProxy Ingress Controller
    local haproxy_class=$(kubectl get ingressclass -o name 2>/dev/null | grep haproxy || echo "")
    if [ ! -z "$haproxy_class" ]; then
        echo "✓ HAProxy Ingress Controller"
        echo "  - Type: Ingress Controller"
        echo "  - IngressClass: $haproxy_class"
        echo "  - Namespace: ingress"
        echo "  - Service: haproxy-ingress"
        echo ""
        found=true
    fi

    # Check for NGINX Gateway Fabric (check for actual gateway resources)
    local nginx_gateway=$(kubectl get gateway -n nginx-gateway -o name 2>/dev/null | grep "gateway.gateway.networking.k8s.io" | head -1 || echo "")
    if [ ! -z "$nginx_gateway" ]; then
        local gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep nginx || echo "")
        echo "✓ NGINX Gateway Fabric"
        echo "  - Type: Gateway Controller"
        echo "  - GatewayClass: $gateway_class"
        echo "  - Namespace: nginx-gateway"
        echo ""
        found=true
    fi

    # Check for Traefik Gateway Controller (check for actual gateway resources)
    local traefik_gateway=$(kubectl get gateway -n traefik-gateway -o name 2>/dev/null | grep "gateway.gateway.networking.k8s.io" | head -1 || echo "")
    if [ ! -z "$traefik_gateway" ]; then
        local traefik_gateway_name=$(echo "$traefik_gateway" | cut -d'/' -f2)
        local gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep traefik || echo "")
        echo "✓ Traefik Gateway Controller"
        echo "  - Type: Gateway Controller"
        echo "  - GatewayClass: $gateway_class"
        echo "  - Namespace: traefik-gateway"
        echo "  - Service: $traefik_gateway_name"
        echo ""
        found=true
    fi

    # Check for Istio Gateway Controller (check for actual gateway resources)
    local istio_gateway=$(kubectl get gateway -n istio-gateway -o name 2>/dev/null | grep "gateway.gateway.networking.k8s.io" | head -1 || echo "")
    if [ ! -z "$istio_gateway" ]; then
        local istio_gateway_name=$(echo "$istio_gateway" | cut -d'/' -f2)
        local gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep istio || echo "")
        echo "✓ Istio Gateway Controller"
        echo "  - Type: Gateway Controller"
        echo "  - GatewayClass: $gateway_class"
        echo "  - Namespace: istio-gateway"
        echo ""
        found=true
    fi

    # Check for NetScaler Gateway Controller (check for actual gateway resources)
    local netscaler_gateway=$(kubectl get gateway -n ingress -o name 2>/dev/null | grep "gateway.gateway.networking.k8s.io" | head -1 || echo "")
    if [ ! -z "$netscaler_gateway" ]; then
        local netscaler_gateway_name=$(echo "$netscaler_gateway" | cut -d'/' -f2)
        local gateway_class=$(kubectl get gatewayclass -o name 2>/dev/null | grep netscaler || echo "")
        echo "✓ NetScaler CPX Gateway Controller"
        echo "  - Type: Gateway Controller"
        echo "  - GatewayClass: $gateway_class"
        echo "  - Namespace: ingress"
        echo "  - Service: $netscaler_gateway_name"
        echo ""
        found=true
    fi

    if [ "$found" = false ]; then
        echo "No controllers installed by this script"
        echo "Note: Other LoadBalancer services may exist but were not installed via this script"
    fi
}


###################### main program ###################
# set -x
# userChoices
function main() {
  # usage prints the script usage
  # Args: $1 - the current script name
  function usage() {
    echo
    echo "Usage: ${0##*/}  [<arguments>] [subscript arguments]"
    echo
    echo " ${0##*/} is a master script that can work in interactive and silent modes to provision data plane"
    echo
    echo "Available options:"
    echo "   [no arguments]                                                          : Interactive Mode"
    echo "   help                                                                    : Prints the usage. If a command was specified, prints usage for that command"
    echo "   [[-c | --config]  <config file path> ]                                  : \"Optional\" Dataplane config file path. \"Default\": \"\$PWD/dpregister.env\""
    # echo "   <-si | --silent  >                                                      : Optional Turns on silent mode"
    echo "   [[-p | --pass | --passsword | -su | --sudo ] <password> ]               : \"Required\" Silent Mode Sudo password argument"
    echo "   [-ss | --show-status ]                                                  : Silent Mode Show status in silent mode"
    echo "   [-ik8s | --installk8s | --install-kubernetes]                           : Silent Mode Install kubernetes on Linux host which supports \"snap package manager\""
    echo "   [-rk8s | --removek8s | --remove-kubernetes]                             : Silent Mode Remove kubernetes on Linux host which supports \"snap package manager\""
    echo "   [[-type |  --type | --k8stype]  <kubernetes type> ]                     : Silent Mode Kubernetes type . \"Default\": microk8s"
    echo "   [-rdp | --register-dp | --register-data-plane]                          : Silent Mode Generates and Runs dataplane config shell script."
    echo "   [-sk | -skip-ngxc |--skip-ngxc | --skip-nginx-controller]               : Silent Mode \"Optional\" Skip Nginx ingress controller installation during dataplane registration"
    echo "   [[-ip | --ipv4 | --ip-addr-ingress-controller ] <ipv4 address> ]        : Silent Mode \"Optional\" IPV4 address of the ingress controller.\"Default\": \$(hostname -I)[0]"
    echo
    echo
    echo "############################################################################################################"
    echo "   Example: ./ ${0##*/} -c [dataplane config]                                    : Run interactive mode"
    echo "   Example: ./ ${0##*/} -p [password] -c [ dataplane config] -rdp -ip [ipv4 address] : Register dataplane and Install and use Nginx Controller"
    echo "   Example: ./ ${0##*/} -p [password] -c [ dataplane config] -rdp -sk            : Register dataplane and Skip Nginx controller"
    echo "   Example: ./ ${0##*/} -p [password] -ik8s -type [kubernetes type]              : Install Kubernetes type on Linux host which supports \"snap package manager\""
    echo "   Example: ./ ${0##*/} -p [password] -rk8s -type [kubernetes type]              : Remove Kubernetes type on Linux host which supports \"snap package manager\""
    echo "   Example: ./ ${0##*/} -p [password] -ss                                        : Show status"
    echo "############################################################################################################"
  }
#   set -x
  # unset SUDO_PASSWORD

  POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -c | --config)
      export DATAPLANE_CONFIG=${2}
      shift # past argument
      [ ! -z "${DATAPLANE_CONFIG}" ] && shift # past argument
      ;;
    # -in | --interactive)
    #   unset SILENT_MODE
    #   CMD="userChoices"
    #   shift # past argument
    #   ;;
    # -si | --silent)
    #   unset SILENT_MODE
    #   export SILENT_MODE="true"
    #   CMD="runSilentMode"
    #   shift # past value
    #   ;;
    -su | --sudo | -p | --pass | --password )
      CMD="runSilentMode"
      export SILENT_MODE="true"
      SUDO_PASSWORD="${2}"
      shift # past argument
      shift # past value
      ;;
    -sk | -skip-ngxc |--skip-ngxc | --skip-nginx-controller)
      CMD="runSilentMode"
      export SILENT_MODE="true"
      SKIP_NGINX_CONTROLLER="true"
      shift # past value
      ;;
    -ip | --ipv4 | --ip-addr-ingress-controller)
      CMD="runSilentMode"
      export SILENT_MODE="true"
      unset INGRESS_IP
      export INGRESS_IP="${2}"
      shift # past argument
      [ ! -z "${INGRESS_IP}" ]  && shift # past value
      ;;
    -ss | --show-status)
      export SILENT_MODE="true"
      CMD="runSilentMode"
      TARGET="showStatus"
      shift # past argument
      ;;

    -type | --type | --k8stype)
      export SILENT_MODE="true"
      CMD="runSilentMode"
      unset K8S_TYPE
      export K8S_TYPE=${2}
      shift # past argument
      [ ! -z "${K8S_TYPE}" ]  && shift # past value
      ;;
    -ik8s | --installk8s | --install-kubernetes)
      export SILENT_MODE="true"
      CMD="runSilentMode"
      TARGET="install_k8s"
      shift # past argument
      ;;
    -rk8s | --removek8s | --remove-kubernetes)
      export SILENT_MODE="true"
      CMD="runSilentMode"
      TARGET="remove_k8s"
      shift # past argument
      ;;
    -rdp | --register-dp | --register-data-plane)
    export SILENT_MODE="true"
      CMD="runSilentMode"
      TARGET="register_dp"
      shift # past argument
      ;;
    help | -h | -help | --help)
      CMD="help"
      shift # past argument
      ;;
    *)                   # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      # CMD="help"
      shift # past argument
      ;;
    esac
  done
  CMD=${CMD:-"userChoices"}


  set -- "${POSITIONAL[@]}" # restore positional parameters
  case ${CMD} in
  runSilentMode)
    runSilentMode ${TARGET}
    ;;
  userChoices)
    userChoices
    ;;
  help)
    usage
    ;;
  esac

  unset SUDO_PASSWORD
}

main ${@}