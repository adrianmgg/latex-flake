{
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) types mkOption;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.trivial) flip pipe;
  inherit (lib.strings) escapeShellArg escapeShellArgs;
in {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    pkgs,
    lib,
    ...
  }: {
    options.latex.texlive = mkOption {type = types.nullOr types.package;};
    options.latex.coreTexlivePackages = mkOption {
      type = types.functionTo (types.listOf types.unspecified);
      default = ps: [ps.scheme-basic ps.latexmk];
    };
    options.latex.texlivePackages = mkOption {
      type = types.functionTo (types.listOf types.unspecified);
      default = ps: [];
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

    config.packages = lib.attrsets.concatMapAttrs (name: doc: let
      texlivePackagesFn = ps:
        (config.latex.coreTexlivePackages ps)
        ++ (config.latex.texlivePackages ps)
        ++ (doc.texlivePackages ps);
      # TODO there's probably a more nix idiomatic way of doing this
      # TODO also this should have a more descriptive name
      getThing = name: default:
        if doc.${name} or null != null
        then doc.${name}
        else if config.latex.${name} or null != null
        then config.latex.${name}
        else default;
      texlive = getThing "texlive" pkgs.texlive.withPackages texlivePackagesFn;
      texFile = doc.texFile;
      root = getThing "root" (dirOf texFile);
      srcWithoutMain =
        if doc.src or null != null
        then doc.src
        else texFile;
      src = lib.fileset.union srcWithoutMain texFile;
      exportBuilder = getThing "exportBuilder" false;
      exportWatchBuilder = getThing "exportWatchBuilder" false;
      pathRelativeToRoot = lib.path.removePrefix root;
      builder = pkgs.writeShellApplication {
        name = "${name}-builder";
        runtimeInputs = [texlive] ++ doc.extraBuildInputs;
        text = ''
          mkdir -p .cache/latex
          latexmk -interaction=nonstopmode -auxdir=.cache/latex -pdf ${escapeShellArg (pathRelativeToRoot texFile)}
        '';
        derivationArgs.strictDeps = true;
      };
      # TODO should explcitly pass --project-origin to watchexec
      buildWatcher = pkgs.writeShellApplication {
        name = "${name}-watch-builder";
        runtimeInputs = [pkgs.watchexec];
        # watchexec seems to work best when called a la `--watch . --filter doc.tex` so we do it that way here
        text = let
          watchArgs = pipe src [
            lib.fileset.toList
            (map pathRelativeToRoot)
            # watchexec doesn't like `./`s in the filter things
            (map (lib.strings.removePrefix "./"))
            # (lib.lists.concatMap (x: ["--watch" x]))
            (lib.lists.concatMap (x: ["--filter" x]))
          ];
        in ''
          watchexec --watch . ${escapeShellArgs watchArgs} -- ${lib.meta.getExe builder}
        '';
        derivationArgs.strictDeps = true;
      };
      pdf = pkgs.stdenvNoCC.mkDerivation {
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
    in
      {
        "${name}" = pdf;
      }
      // optionalAttrs exportBuilder {
        "${name}-build" = builder;
      }
      // optionalAttrs exportWatchBuilder {
        "${name}-watch-builder" = buildWatcher;
      })
    config.latex.documents;
  });
}
