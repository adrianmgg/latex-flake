{
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) types mkOption;
in {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    pkgs,
    lib,
    ...
  }: {
    options.latex.texlive = mkOption {type = types.nullOr types.package;};
    options.latex.texlivePackages = mkOption {
      type = types.functionTo (types.listOf types.unspecified);
      default = ps: [ps.scheme-basic ps.latexmk];
    };
    options.latex.exportBuilder = mkOption {
      type = types.bool;
      default = false;
    };
    options.latex.exportWatchBuilder = mkOption {
      type = types.bool;
      default = false;
    };
    options.latex.exportTexlive = mkOption {
      type = types.bool;
      default = false;
    };
    options.latex.documents = mkOption {
      type = types.attrsOf (types.submodule {
        options.texFile = mkOption {type = types.path;};
        options.src = mkOption {type = types.nullOr types.fileset;};
        options.root = mkOption {type = types.nullOr types.path;};
        options.texlive = mkOption {type = types.nullOr types.package;};
        options.texlivePackages = mkOption {
          type = types.functionTo (types.listOf types.package);
          default = ps: [];
        };
        options.extraBuildInputs = mkOption {
          type = types.listOf types.package;
          default = [];
        };
        options.exportBuilder = mkOption {type = types.nullOr types.bool;};
        options.exportWatchBuilder = mkOption {type = types.nullOr types.bool;};
        options.exportTexlive = mkOption {type = types.nullOr types.bool;};
        options.version = mkOption {
          type = types.str;
          default = "1";
        };
      });
    };

    config.packages =
      lib.attrsets.concatMapAttrs (name: doc: let
        texlivePackagesFn = ps:
          (config.latex.texlivePackages ps)
          ++ (doc.texlivePackages ps);
        texlive =
          if doc.texlive or null != null
          then doc.texlive
          else if config.latex.texlive or null != null
          then config.latex.texlive
          else pkgs.texlive.withPackages texlivePackagesFn;
        root =
          if doc.root or null != null
          then doc.root
          else if config.latex.root or null != null
          then config.latex.root
          else dirOf doc.texFile;
        src =
          if doc.src or null != null
          then doc.src
          else doc.texFile;
        texPathRelativeToRoot = lib.path.removePrefix root doc.texFile;
        builder = pkgs.writeShellApplication {
          name = "${name}-builder";
          runtimeInputs = [texlive] ++ doc.extraBuildInputs;
          text = ''
            mkdir -p .cache/latex
            latexmk -interaction=nonstopmode -auxdir=.cache/latex -pdf ${lib.strings.escapeShellArg texPathRelativeToRoot}
          '';
        };
        # buildWatcher = pkgs.writeShellApplication {
        #   name = "${name}-watch-builder";
        #   runtimeInputs = [builder pkgs.watchexec];
        #   text = ''
        #     watchexec -e tex,bib -- build-pdf
        #   '';
        # };
        pdf = pkgs.stdenv.mkDerivation {
          pname = name;
          inherit (doc) version;
          src = lib.fileset.toSource {
            fileset = src;
            inherit root;
          };
          buildInputs = [builder];
          buildPhase = ''
            ${lib.escapeShellArg "${name}-builder"}
          '';
          installPhase = ''
            mkdir -p $out
            cp *.pdf $out/
          '';
          dontFixup = true;
        };
      in {
        "${name}" = pdf;
      })
      config.latex.documents;
  });
}
