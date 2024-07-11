{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    argo
    kubectl
    kustomize
    google-cloud-sdk
    github-cli
    opentofu
  ];
}
