{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
let
  pname = "license-server";
  version = "775b01bbf4bc2eb683f7cfa45d47389c91bf4c67";

  src = fetchFromGitHub {
    owner = "postula";
    repo = "autostandup";
    rev = version;
    hash = lib.fakeHash;
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = lib.fakeHash;

  # Build only the license-server crate from the workspace
  cargoBuildFlags = [
    "-p"
    "license-server"
  ];
  cargoTestFlags = [
    "-p"
    "license-server"
  ];

  # sqlx offline mode - no database needed at build time
  # Requires .sqlx directory with cached query metadata in the source
  env.SQLX_OFFLINE = "true";

  meta = {
    description = "License server for AutoStandup";
    homepage = "https://github.com/postula/autostandup"; # TODO: fill in
    license = lib.licenses.mit; # TODO: verify license
    maintainers = with lib.maintainers; [ loispostula ];
    mainProgram = "license-server";
  };
}
