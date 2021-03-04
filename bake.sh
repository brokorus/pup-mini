function dockerCheck () {
  if docker images > /dev/null; then
    now="$(date +'%j-%T')"
    echo 'Docker successfully installed, Warning!!!'
    echo 'THIS SCRIPT WILL DELETE YOUR EXISTING MINIKUBE CLUSTER'
    echo 'THIS SCRIPT WILL install minikube if it does not exist'
    echo 'THIS SCRIPT WILL REPLACE BUT BACKUP YOUR EXISTING KUBERNETES CONTEXT'
    echo "IF YOUR CONTEXT EXISTED BEFORE, IT IS NOW AT ~/.kube/config.backup.$now"
    while true; do
    read -p "Do you wish to run this demo given the previous conditions? y/n: > " yn
      case $yn in
          [Yy]* ) echo 'Running demo'; sleep 1; 
             cp ~/.kube/config ~/.kube/config.backup.$now
             break
             ;;
          [Nn]* ) echo 'Exiting'; exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  else
    echo "Please install and or start Docker run this demo"
    exit
  fi
}

checkExist () {
  if echo "$(basename $(pwd))" == "pup-mini"; then
    echo 'Code challenge already exists locally'
  else
    docker run -ti --rm -v ${HOME}:/root -v $(pwd):/git alpine/git clone git@github.com:brokorus/pup-mini.git
    cd pup-mini
  fi
  export parentDir=$(pwd)
}

function installPuppetServer () {
  helm install puppetserver ./charts/puppetserver-helm-chart
}

function kubeConfig () {
  kubernetesip=$(kubectl get svc --namespace default kubernetes -o jsonpath="{.spec.clusterIP}")
  home=~; cat ~/.kube/config | sed "s|$home|\~|" | sed "s|~/.minikube/profiles||" | sed "s|~/.minikube|/minikube|" | sed "s|server: https://127.0.0.1.*|server: https://$kubernetesip:443|" > kubeconf
  home=~; kubectl -n kube-system create secret generic minica --from-file=$home/.minikube/ca.crt
  home=~; kubectl -n kube-system create secret generic minicrt --from-file=$home/.minikube/profiles/minikube/client.crt
  home=~; kubectl -n kube-system create secret generic minikey --from-file=$home/.minikube/profiles/minikube/client.key
  home=~; kubectl -n kube-system create secret generic miniconfig --from-file=kubeconf
}

function minikubeSetup () {
if minikube version; then
  echo 'Minikube installed resetting environment'
else
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        minikube kubectl
      ;;
      Darwin*)    
        brew install kubectl minikube
      ;;
      CYGWIN*)    
        set +e
        winget install minikube
        choco install minikube
        set -e
        if minikube version; then
          echo 'Minikube installed successfully'
          minikube kubectl
        else 
          curl -o minikube_installer.exe https://storage.googleapis.com/minikube/releases/latest/minikube-installer.exe
          echo 'Minikube failed to install, trying manual installation'
          ./minikube_installer.exe
          minikube kubectl
        fi
      ;;
      MINGW*)     
        set +e
        winget install minikube
        choco install minikube
        set -e
        if minikube version; then
          echo 'Minikube installed successfully'
          minikube kubectl
        else 
          curl -o minikube_installer.exe https://storage.googleapis.com/minikube/releases/latest/minikube-installer.exe
          echo 'Minikube failed to install, trying manual installation'
          ./minikube_installer.exe
          minikube kubectl
        fi
        ;;
      *)          machine="UNKNOWN:${unameOut}"
  esac
fi
minikube delete 
minikube start --memory=9000 --cpus=4 
eval $(minikube docker-env)
}


function puppetDockerBuild () {
  cd $1
  docker run -v /var/run/docker.sock:/var/run/docker.sock -v $1:/build --privileged -w /build -i puppet-docker-builder:0.1.0 /opt/puppetlabs/bin/puppet docker build 
  cd $parentDir
}

function portForward () {
  export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=$1,app.kubernetes.io/instance=$1" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace default $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  kubectl --namespace default port-forward $POD_NAME $2:$CONTAINER_PORT &
}

function buildToolImage () {
cat <<EOF > dockerfile
FROM ubuntu:20.04

RUN apt-get update && \
    apt-transport-https \
    software-properties-common \
    ca-certificates \
    lsb-release \
    wget \
    curl \
    git \
    gnupg -y

RUN wget https://apt.puppetlabs.com/puppet6-release-focal.deb && \
    dpkg -i puppet6-release-focal.deb && \
    apt-get update && \
    apt-get install puppet-agent && \
    /opt/puppetlabs/bin/puppet module install puppetlabs-image_build
EOF
docker build -t puppet-docker-builder:0.1.0 .
}

function installDockerRegistry () {
docker run -it -w /charts -v $(pwd)/charts:/charts -v ~/.kube:/root/.kube dtzar/helm-kubectl  helm install ./docker-registry
}

# check if system meets pre-reqs
dockerCheck 

# Accomodate for remote curl pipe
checkExist

# If minikube not installed, install
minikubeSetup

# Setup docker registry for puppet docker builds
installDockerRegistry

buildToolImage 

#puppetDockerBuild $(pwd)/docker-puppet-modules/apache/

kubeConfig

installPuppetServer

#portForward wetty 3000

#configureDockerRegistry 
