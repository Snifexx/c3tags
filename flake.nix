{
  description = "Shell";

  inputs = {
    nixpkgs.url = "nixpkgs/648f70160c03151bc2121d179291337ad6bc564b";
  };

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
      name = "c3tags-test";
      srcs = [ ./src ./libs ];
      sourceRoot = ".";

      buildInputs = with pkgs; [
        c3c c3-lsp
        tree-sitter
      ];

      make3 = ./make3.c3;

      postUnpack = ''
        cp "$make3" .
      '';

      buildPhase = ''
        ls
        c3c compile -o c3tags src/* $make3 libs/tree-sitter/tree-sitter.c3i libs/tree-sitter-c3/tree_sitter_c3.c3i \
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
