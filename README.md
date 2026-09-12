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

# managing latex dependencies

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

In order, this is how the texlive package for a particular document is decided:
1. `latex.documents.<name>.texlive`, if specified.
2. `latex.texlive`, if specified.
3. both `latex.texlivePackages` and `latex.documents.<name>.texlivePackages`, merged together

# options
## `latex.texlive`
manually set your own texlive package. you should typically use `latex.texlivePackages` instead.

## `latex.texlivePackages`
A function which will be passed to `pkgs.texlive.withPackages` to resolve your texlive packages used by all documents.

Example:
```nix
latex.texlivePackages = ps: with ps; [scheme-basic latexmk xcolor];
```

## `latex.exportBuilder`
Should a `<name>-builder` package also be exposed for each document?
(This can be used to build the document without putting the compiled pdf in the nix store. e.g. `nix run .#mydocument-build`)

## `latex.exportWatchBuilder`
Should a `<name>-watch-builder` package also be exposed for each document?
(This is like `latex.exportBuilder`, but with a script that will watch for changes to the source files and automatically re-build the document when they're changed.)

> [!WARNING]
> This isn't implemented yet!

## `latex.exportTexlive`
Should the resolved texlive package for each document also be exposed?

> [!WARNING]
> This isn't implemented yet!

## `latex.documents.<name>.texFile`
The main source file for this document.

## `latex.documents.<name>.src`
A fileset containing all the input files this document requires.
If not specified, defaults to a fileset containing just this document's `.texFile`.

## `latex.documents.<name>.root`
Root used to resolve the `src` fileset into a store path via `lib.fileset.toSource`.
If not specified, defaults to the parent directory of this document's `texFile`.

## `latex.documents.<name>.texlive`
Like `latex.texlive`, but for just this document.

## `latex.documents.<name>.texlivePackages`
Specify additional packages for just this document, to be merged together with the global `latex.texlivePackages`.

## `latex.documents.<name>.extraBuildInputs`
Additional packages needed to build this document, other than the latex ones.

## `latex.documents.<name>.exportBuilder`
Like `latex.exportBuilder`, but for just this document.

## `latex.documents.<name>.exportWatchBuilder`
Like `latex.exportWatchBuilder`, but for just this document.

## `latex.documents.<name>.exportTexlive`
Like `latex.exportTexlive`, but for just this document.

## `latex.documents.<name>.version`
Version number for the derivation that builds this document.
If not specified, defaults to `1`.

