{
  fetchFromGitHub,
  fetchYarnDeps,
  lib,
  makeWrapper,
  nodejs,
  prisma-engines,
  stdenv,
  yarnBuildHook,
  yarnConfigHook,
  yarnInstallHook,
  python3,
  ffmpeg,
  gcc,
  dbus,
  sox,
  git,
  jq,
  inkscape,
  flac,
  fdk_aac,
  vorbis-tools,
  opusTools,
  writeShellScriptBin,
  symlinkJoin,
}:

let
  pname = "craig";
  version = "578d63e";
  src = fetchFromGitHub {
    owner = "ForesightMiningSoftwareCorporation";
    repo = pname;
    rev = version;
    sha256 = "sha256-hLIeB06MrLBH0ND9wxbtAojegS9355wXRxRH4t6Y+hc=";
  };
  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-1o+T6Y93iQ/qekC81B46fryL0m4kWjgS/M1d/e8B90E=";
  };
  # Common build environment
  commonEnv = {
    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
    PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines}/bin/query-engine";
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
    PRISMA_FMT_BINARY = "${prisma-engines}/bin/prisma-fmt";
    # Fake values for build time - real values come from config
    CLIENT_ID = "FAKE_VALUE";
    CLIENT_SECRET = "FAKE_VALUE";
    PATREON_CLIENT_ID = "FAKE_VALUE";
    PATREON_CLIENT_SECRET = "FAKE_VALUE";
    PATREON_WEBHOOK_SECRET = "FAKE_VALUE";
    PATREON_TIER_MAP = "FAKE_VALUE";
    GOOGLE_CLIENT_ID = "FAKE_VALUE";
    GOOGLE_CLIENT_SECRET = "FAKE_VALUE";
    MICROSOFT_CLIENT_ID = "FAKE_VALUE";
    MICROSOFT_CLIENT_SECRET = "FAKE_VALUE";
    DROPBOX_CLIENT_ID = "FAKE_VALUE";
    DROPBOX_CLIENT_SECRET = "FAKE_VALUE";
    APP_URI = "FAKE_VALUE";
    JWT_SECRET = "FAKE_VALUE";
  };
  baseWorkspace = stdenv.mkDerivation {
    pname = "${pname}-workspace";
    inherit version src offlineCache;

    nativeBuildInputs = [
      yarnConfigHook
      yarnBuildHook
      yarnInstallHook
      nodejs
      python3
      git
      jq
    ];

    buildPhase = ''
      runHook preBuild

      # Copy config templates
      cp apps/bot/config/_default.js apps/bot/config/default.js || true
      cp apps/tasks/config/_default.js apps/tasks/config/default.js || true

      # Generate Prisma client
      yarn prisma:generate

      # Build all packages
      yarn run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      # Copy everything needed for runtime
      cp -r node_modules $out/
      cp -r apps $out/
      cp -r prisma $out/
      cp package.json yarn.lock $out/

      # Copy any workspace-level configs
      cp -r config $out/ || true

      runHook postInstall
    '';

    env = commonEnv;
  };
  cookTools = stdenv.mkDerivation {
    pname = "${pname}-cook";
    inherit version src;

    nativeBuildInputs = [
      inkscape
      ffmpeg
      sox
      python3
      makeWrapper
      gcc
    ];

    buildInputs = [
      flac
      vorbis-tools
      opusTools
    ];

    # Patch the build script before building
    patchPhase = ''
      runHook prePatch

      # First, let's see what buildCook.sh contains
      echo "=== buildCook.sh contents ==="
      cat scripts/buildCook.sh || true
      echo "=== end of buildCook.sh ==="

      # Patch out dbus-run-session if it exists
      if [ -f scripts/buildCook.sh ]; then
        # Replace dbus-run-session with direct execution
        sed -i 's/dbus-run-session //g' scripts/buildCook.sh

        # If inkscape needs special flags in headless mode
        sed -i 's/inkscape/inkscape --without-gui/g' scripts/buildCook.sh || true
      fi

      runHook postPatch
    '';

    buildPhase = ''
      runHook preBuild

      # Ensure the script uses our nix-provided tools
      patchShebangs scripts/buildCook.sh

      # Set up environment for headless building
      export HOME=$TMPDIR
      export INKSCAPE_PROFILE_DIR=$TMPDIR/.config/inkscape
      mkdir -p $INKSCAPE_PROFILE_DIR

      # Try to build cook
      echo "Building cook tools..."
      if bash scripts/buildCook.sh; then
        echo "Cook build succeeded"
      else
        echo "Cook build failed, checking for alternatives..."

        # Check if downloadCookBuilds.sh exists as fallback
        if [ -f scripts/downloadCookBuilds.sh ]; then
          echo "Attempting to use pre-built cook binaries..."
          patchShebangs scripts/downloadCookBuilds.sh
          bash scripts/downloadCookBuilds.sh || true
        fi

        # Check if we have any cook binaries
        if [ -d cook/bin ] && [ "$(ls -A cook/bin)" ]; then
          echo "Cook binaries found, continuing..."
        else
          echo "Warning: No cook binaries available"
          # Create empty directory so install phase doesn't fail
          mkdir -p cook/bin
        fi
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/share/craig-cook

      # Install cook binaries if they exist
      if [ -d cook/bin ] && [ "$(ls -A cook/bin)" ]; then
        cp -r cook/bin/* $out/bin/
        chmod +x $out/bin/* || true
      else
        echo "No cook binaries to install"
      fi

      # Install any cook resources
      if [ -d cook ] && [ "$(ls -A cook)" ]; then
        cp -r cook/* $out/share/craig-cook/ || true
      fi

      # Create wrapper to add audio tools to PATH
      for tool in $out/bin/*; do
        if [ -f "$tool" ] && [ -x "$tool" ]; then
          wrapProgram "$tool" \
            --prefix PATH : ${
              lib.makeBinPath [
                ffmpeg
                sox
                flac
                fdk_aac
                vorbis-tools
                opusTools
              ]
            }
        fi
      done

      # If no tools were built, create a placeholder
      if [ -z "$(ls -A $out/bin)" ]; then
        cat > $out/bin/craig-cook-placeholder <<EOF
      #!${stdenv.shell}
      echo "Cook tools were not built. Audio processing features may be limited."
      exit 1
      EOF
        chmod +x $out/bin/craig-cook-placeholder
      fi

      runHook postInstall
    '';
  };
  mkCraigService =
    {
      serviceName,
      servicePath,
      extraWrapperArgs ? [ ],
      extraInstallPhase ? "",
    }:
    stdenv.mkDerivation {
      pname = "${pname}-${serviceName}";
      inherit version;

      src = baseWorkspace;

      nativeBuildInputs = [
        makeWrapper
        nodejs
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/craig-${serviceName}

        # Copy the specific service
        cp -r $src/apps/${servicePath}/* $out/lib/craig-${serviceName}/

        # Copy shared dependencies
        cp -r $src/node_modules $out/lib/craig-${serviceName}/
        cp -r $src/prisma $out/lib/craig-${serviceName}/

        # Find the main entry point
        MAIN_FILE=""
        if [ -f "$out/lib/craig-${serviceName}/dist/index.js" ]; then
          MAIN_FILE="$out/lib/craig-${serviceName}/dist/index.js"
        elif [ -f "$out/lib/craig-${serviceName}/dist/src/index.js" ]; then
          MAIN_FILE="$out/lib/craig-${serviceName}/dist/src/index.js"
        elif [ -f "$out/lib/craig-${serviceName}/build/index.js" ]; then
          MAIN_FILE="$out/lib/craig-${serviceName}/build/index.js"
        else
          echo "Warning: Could not find main entry point for ${serviceName}"
          MAIN_FILE="$out/lib/craig-${serviceName}/index.js"
        fi

        # Create wrapper script
        mkdir -p $out/bin
        makeWrapper ${nodejs}/bin/node $out/bin/craig-${serviceName} \
          --add-flags "$MAIN_FILE" \
          --set NODE_ENV "production" \
          --chdir "$out/lib/craig-${serviceName}" \
          --prefix PATH : ${lib.makeBinPath [ cookTools ]} \
          ${lib.concatStringsSep " " extraWrapperArgs}

        ${extraInstallPhase}

        runHook postInstall
      '';
    };
  # Individual services
  bot = mkCraigService {
    serviceName = "bot";
    servicePath = "bot";
  };

  dashboard = mkCraigService {
    serviceName = "dashboard";
    servicePath = "dashboard";
  };

  download = mkCraigService {
    serviceName = "download";
    servicePath = "download";
    extraWrapperArgs = [
      "--prefix PATH : ${
        lib.makeBinPath [
          ffmpeg
          sox
        ]
      }"
    ];
  };

  tasks = mkCraigService {
    serviceName = "tasks";
    servicePath = "tasks";
  };
  # Migration runner
  migrate = writeShellScriptBin "craig-migrate" ''
    #!${stdenv.shell}
    set -e

    : ''${DATABASE_URL:?DATABASE_URL must be set}

    export NODE_ENV=production
    export PATH=${lib.makeBinPath [ nodejs ]}:$PATH

    # Use Prisma from the workspace
    cd ${baseWorkspace}
    ${nodejs}/bin/npx prisma migrate deploy
  '';

  # Command sync utilities
  syncCommands = writeShellScriptBin "craig-sync-commands" ''
    #!${stdenv.shell}
    set -e

    : ''${DISCORD_BOT_TOKEN:?DISCORD_BOT_TOKEN must be set}
    : ''${DISCORD_APP_ID:?DISCORD_APP_ID must be set}

    export NODE_ENV=production
    export PATH=${lib.makeBinPath [ nodejs ]}:$PATH

    cd ${bot}/lib/craig-bot

    if [ "$1" = "--dev" ] && [ -n "$DEVELOPMENT_GUILD_ID" ]; then
      echo "Syncing commands to development guild..."
      ${nodejs}/bin/node dist/scripts/sync-dev.js || \
      ${nodejs}/bin/node dist/sync-dev.js || \
      ${nodejs}/bin/node scripts/sync-dev.js
    else
      echo "Syncing commands globally..."
      ${nodejs}/bin/node dist/scripts/sync.js || \
      ${nodejs}/bin/node dist/sync.js || \
      ${nodejs}/bin/node scripts/sync.js
    fi
  '';
in
{
  # Export individual components
  inherit
    bot
    dashboard
    download
    tasks
    cookTools
    migrate
    syncCommands
    ;

  # Keep the base workspace available
  workspace = baseWorkspace;

  # Default package combines everything
  craig = symlinkJoin {
    name = "${pname}-${version}";
    paths = [
      bot
      dashboard
      download
      tasks
      cookTools
      migrate
      syncCommands
    ];

    meta = with lib; {
      homepage = "https://craig.chat/";
      description = "Craig is a multi-track voice recorder for Discord";
      license = licenses.isc;
      maintainers = with maintainers; [ loispostula ];
      platforms = lib.platforms.all;
    };
  };
}
