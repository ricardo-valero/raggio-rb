{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = {nixpkgs, ...}: let
    systems = nixpkgs.lib.systems.flakeExposed;
  in {
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = builtins.attrValues {
          inherit (pkgs) git nixd alejandra;
          ruby = pkgs.ruby.withPackages (r: with r; [ruby-lsp]);
        };
        env.RUBYOPT = "-W0";
      };
    });
  };
}
