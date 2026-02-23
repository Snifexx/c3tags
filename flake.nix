{
  description = "Shell";

  inputs = {
    nixpkgs.url = "nixpkgs/648f70160c03151bc2121d179291337ad6bc564b";
  };

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        c3c c3-lsp
        tree-sitter
      ];

      shellHook = ''
        export SHELL="$(which fish)"
        $SHELL 
      '';
      
      libmoves = "c3c dynamic-lib ./datagen/out/moves.c3 --linux-crt /nix/store/1f0rwgif0bk36z8y2np96jyl7vl0926z-glibc-2.39-52/lib --linux-crtbegin /nix/store/dih8vf5naf93c0wcfxqa9pll3k7iv9bm-gcc-14-20241116/lib64/gcc/x86_64-unknown-linux-gnu/14.2.1 --target elf-x64 -o libmoves --reloc=PIC";
    };
  };
}
