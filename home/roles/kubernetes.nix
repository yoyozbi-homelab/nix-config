{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    kubectx
    envsubst
    kubernetes-helm
    minikube
  ];
}
