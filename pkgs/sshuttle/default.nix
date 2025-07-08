{
  lib,
  fetchFromGitHub,
  python3,
}:
let
  pname = "sshuttle";
  version = "v1.3.1";
  src = fetchFromGitHub {
    owner = "sshuttle";
    repo = pname;
    tag = version;
    # sha256 = lib.fakeSha256;
    sha256 = "sha256-/ThWsPtFuUo41+Xw23UigZup1fq6/SAzDpxIaT0Vhvg=";
  };
in
python3.pkgs.buildPythonApplication rec {
  inherit src pname version;
  format = "pyproject";

  propagatedBuildInputs = with python3.pkgs; [
  ];

  nativeBuildInputs =  with python3.pkgs; [
    hatchling
  ];

  meta = with lib; {
    homepage = "https://github.com/sshuttle/sshuttle";
    description = "Transparent proxy server that works as a poor man's VPN. Forwards over ssh. Doesn't require admin. Works with Linux and MacOS. Supports DNS tunneling. ";
    license = licenses.lgpl21Only;
    maintainers = with maintainers; [ loispostula ];
  };
}
