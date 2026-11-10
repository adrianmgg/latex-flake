{
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) types mkOption;
  inherit (lib.attrsets) optionalAttrs;
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
        inherit (lib.strings) escapeShellArg;
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
        exportBuilder =
          if doc.exportBuilder or null != null
          then doc.exportBuilder
          else if config.latex.exportBuilder or null != null
          then config.latex.exportBuilder
          else false;
        texPathRelativeToRoot = lib.path.removePrefix root doc.texFile;
        builder = pkgs.writeShellApplication {
          name = "${name}-builder";
          runtimeInputs = [texlive] ++ doc.extraBuildInputs;
          text = ''
            mkdir -p .cache/latex
            latexmk -interaction=nonstopmode -auxdir=.cache/latex -pdf ${escapeShellArg texPathRelativeToRoot}
          '';
          derivationArgs.strictDeps = true;
        };
        buildWatcher = pkgs.writeShellApplication {
          name = "${name}-watch-builder";
          runtimeInputs = [builder pkgs.watchexec];
          # text = ''
          #   watchexec --watch-file TODO -- ${escapeShellArg (lib.getExe builder)}
          # '';
          text = ''
            watchexec --watch-file TODO -- ${escapeShellArg builder.name}
          '';
          derivationArgs.strictDeps = true;
        };
        # TODO look @ using runCommand instead?
        pdf = pkgs.stdenv.mkDerivation {
          pname = name;
          inherit (doc) version;
          src = lib.fileset.toSource {
            fileset = src;
            inherit root;
          };
          nativeBuildInputs = [builder];
          buildPhase = ''
            ${escapeShellArg builder.name}
          '';
          installPhase = ''
            mkdir -p $out
            cp *.pdf $out/
          '';
          dontFixup = true;
          strictDeps = true;
        };
      in {
        "${name}" = pdf;
      } // optionalAttrs exportBuilder {
        "${name}-build" = builder;
      })
      config.latex.documents;
  });
}
