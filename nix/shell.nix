{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    argo
    kubectl
    kustomize
    google-cloud-sdk
    opentofu
    rnix-lsp
  ];
}
