{ stdenv, python3Packages }:
with python3Packages;
let
  name = "LazyLibrarian";
  version = "976da958c9aa8d90f6dc7a178b6fb4ba102f2835";
in
buildPythonPackage {
  inherit version;
  pname = name;
  format = "pyproject";
  src = pkgs.fetchFromGitLab {
    owner = name;
    repo = name;
    rev = version;
    sha256 = "sha256-m7pK+HiUIkOLbnQaloE4m3YFTbYUxmeQ3fFlLgQDE2U=";
  };

  preConfigure = ''
    ${pkgs.gnused}/bin/sed -i 's/, "ez_setup"//g' pyproject.toml
  '';
  propagatedBuildInputs = with pkgs; [
    beautifulsoup4
    html5lib
    webencodings
    requests
    urllib3
    pyopenssl
    cherrypy
    cherrypy-cors
    httpagentparser
    mako
    httplib2
    pillow
    apprise
    pypdf3
    python-magic
    rapidfuzz
    deluge-client
    pyparsing
    irc

    setuptools
  ];

  meta = with lib; {
    description = "LazyLibrarian is a SickBeard, CouchPotato, Headphones-like application for ebooks, audiobooks and magazines";
    homepage = "https://gitlab.com/LazyLibrarian/LazyLibrarian";
    license = licenses.gpl3;
    maintainers = with maintainers; [ loispostula ];
  };

}
