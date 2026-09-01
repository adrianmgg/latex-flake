still very wip, expect some things to be broken and API to probably change

simple flake using this:
```nix
{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    latex-flake.url = "github:adrianmgg/latex-flake";
  };
  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.latex-flake.flakeModule
      ];
      systems = ["x86_64-linux"];
      perSystem = { ... }: {
        latex.documents.hello.texFile = ./hello-world.tex;
      };
    };
}
```

then, doing
```bash
nix build .#hello
```
will build the pdf

---

managing latex dependencies:
```nix
# you can add dependencies to just one document:
latex.documents.hello = {
  texFile = ./hello-world.tex;
  texlivePackages = ps: with ps; [scheme-basic latexmk xcolor];
};
# WARNING: currently, you need to make sure to include latexmk or the pdf will fail to build

# you can add dependencies to all documents:
latex.texlivePackages = ps: with ps; [scheme-basic latexmk];
latex.documents.foo.texFile = ./foo.tex;
latex.documents.bar = {
  texFile = ./bar.tex;
  # per-document list will be merged with the top-level one,
  # so this will still get [scheme-basic latexmk] from the top-level too.
  texlivePackages = ps: with ps; [xcolor];
};

# you can also set texlive manually instead of using the mechanism above.
# latex.texlive, if set, will be used instead of .texlivePackages
latex.texlive = pkgs.texlive.withPackages (ps: with ps; [scheme-basic latexmk xcolor]);
latex.documents.foo = {
  texFile = ./foo.tex;
  # setting .texlive on a specific document does the same but for just that document
  texlive = /* ... */;
};
```


