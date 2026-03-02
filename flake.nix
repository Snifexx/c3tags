{
  description = "C3Tags dev shell and package";

  inputs = {
    nixpkgs.url = "nixpkgs/648f70160c03151bc2121d179291337ad6bc564b";
  };

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
      pname = "c3tags";
      version = "1.0";
      src = ./.;

      buildInputs = with pkgs; [
        c3c c3-lsp
        tree-sitter
      ];

      buildPhase = ''
        ls
        c3c compile -o c3tags src/* make3.c3 libs/tree-sitter/tree-sitter.c3i libs/tree-sitter-c3/tree_sitter_c3.c3i \
          -l tree-sitter -L ${pkgs.tree-sitter}/lib \
          -l tree-sitter-c3 -L libs/tree-sitter-c3 
      '';

      installPhase = ''
        mkdir -p "$out/bin"
        cp ./c3tags "$out/bin"
      '';
    };
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        c3c c3-lsp
        tree-sitter
      ];

      shellHook = ''
        export SHELL="$(which fish)"
        $SHELL 
      '';
    };
  };
}
