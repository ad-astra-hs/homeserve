{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-gleam.url = "github:arnarg/nix-gleam";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-gleam,
  }: (
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-gleam.overlays.default
        ];
      };

      app = pkgs.buildGleamApplication {
        src = ./.;
      };
    in {
      packages.default = app;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          nixd
          nil
          gleam
          erlang
          rebar3
          inotify-tools
          elixir
          bacon
        ];
      };
      formatter = pkgs.alejandra;
    })
  );
}
