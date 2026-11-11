{
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) types mkOption;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.trivial) flip pipe;
  inherit (lib.strings) escapeShellArg escapeShellArgs;
  inherit (lib.lists) optional;
  latexEngineType = types.enum ["pdflatex" "lualatex" "xelatex"];
  # TODO probably shouldn't be unspecified...
  texliveWithPackagesFunctionType = types.functionTo (types.listOf types.unspecified);
in {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.latex;
  in {
    options.latex.engine = mkOption {
      type = latexEngineType;
      default = "pdflatex";
    };
    options.latex.texlive = mkOption {type = types.nullOr types.package;};
    options.latex.coreTexlivePackages = mkOption {
      type = texliveWithPackagesFunctionType;
      default = ps:
        [ps.scheme-basic ps.latexmk]
        ++ optional (cfg.engine == "lualatex") ps.luatex
        ++ optional (cfg.engine == "xelatex") ps.xetex;
    };
    options.latex.texlivePackages = mkOption {
      type = texliveWithPackagesFunctionType;
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
        options.engine = mkOption {type = types.nullOr latexEngineType;};
        options.texlive = mkOption {type = types.nullOr types.package;};
        options.texlivePackages = mkOption {
          type = texliveWithPackagesFunctionType;
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

    config.packages = flip lib.attrsets.concatMapAttrs cfg.documents (name: doc: let
      texlivePackagesFn = ps:
        (cfg.coreTexlivePackages ps)
        ++ (cfg.texlivePackages ps)
        ++ (doc.texlivePackages ps);
      # TODO there's probably a more nix idiomatic way of doing this
      # TODO also this should have a more descriptive name
      getThing = name: default:
        if doc.${name} or null != null
        then doc.${name}
        else if cfg.${name} or null != null
        then cfg.${name}
        else default;
      getThing' = name:
        if doc.${name} or null != null
        then doc.${name}
        else cfg.${name};
      engine = getThing' "engine";
      texlive = getThing "texlive" (pkgs.texlive.withPackages texlivePackagesFn);
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
        # NOTE this just does -${engine} for now since with the current options & option names that's sufficient.
        #      should probably improve that at some point tho.
        text = ''
          mkdir -p .cache/latex
          latexmk -interaction=nonstopmode ${escapeShellArg "-${engine}"} -auxdir=.cache/latex -pdf ${escapeShellArg (pathRelativeToRoot texFile)}
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
      });
  });
}
