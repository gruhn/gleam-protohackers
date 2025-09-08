{
  description = "Elixir development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            beamMinimal28Packages.elixir_1_19
            beamMinimal28Packages.elixir-ls
            beamMinimal28Packages.erlang
            erlang-language-platform
            inetutils # for telnet

            gleam
            beamMinimal28Packages.rebar3
          ];
        };
      });
}
