{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    krew
    k9s
    kubernetes-helm
    terraform
    terraformOSS
    tfk8s
    pulumi-bin
  ];
}
