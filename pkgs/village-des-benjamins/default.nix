{
  lib,
  writeText,
  fetchFromGitHub,
  fetchurl,
  fetchPypi,
  nixosTests,
  python3,
  gettext,
  buildNpmPackage,
  nodejs_latest,
  importNpmLock,
}:
let
  py = python3.override {
    self = python3;
    packageOverrides = final: prev: {
      django = prev.django_5;
    };
  };
  # Dependencies
  pyPkgcommonConfig = {
    nativeBuildInputs = [ py.pkgs.setuptools ];
    doCheck = false;
    propagatedBuildInputs = [ py.pkgs.django_5 ];
  };
  django-jazzmin =
    py.pkgs.buildPythonPackage rec {
      pname = "django-jazzmin";
      version = "3.0.1";
      src = fetchurl {
        url = "https://files.pythonhosted.org/packages/ad/5b/2f8c4b168e6c41bf1e4b14d787deb23d80f618f0693db913bbe208a4a907/django_jazzmin-3.0.1-py3-none-any.whl";
        sha256 = "sha256-EqCkwdT9CcLu8irPah8DEStRW6aVxZ+qjqgO/IHB8hs=";
      };
      format = "wheel";
    }
    // pyPkgcommonConfig;
  django-better-admin-arrayfield =
    py.pkgs.buildPythonPackage rec {
      pname = "django-better-admin-arrayfield";
      version = "1.4.2";
      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-tFQj5Ru8CqMe9lgkjAWMqLUzpUG+Te6fuLzQWfihClg=";
      };
      pyproject = true;
      build-system = [ py.pkgs.setuptools ];
    }
    // pyPkgcommonConfig;
  django-ordered-model =
    py.pkgs.buildPythonPackage rec {
      pname = "django-ordered-model";
      version = "3.7.4";
      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-8li5diUlwApTAJ6C+Li/KjqjFei0U+KB6P27/iuMs7o=";
      };
      pyproject = true;
      build-system = [ py.pkgs.setuptools ];
    }
    // pyPkgcommonConfig;
  django-colorfield = py.pkgs.buildPythonPackage rec {
    pname = "django-colorfield";
    version = "0.14.0";
    src = fetchPypi {
      inherit version;
      pname = "django_colorfield";
      sha256 = "sha256-R429OXWojy6iqa/DJfqsoFxU6/BOyYXOEw9t6jnfuJk=";
    };
    pyproject = true;
    build-system = [ py.pkgs.setuptools ];
    nativeBuildInputs = [ py.pkgs.setuptools ];
    propagatedBuildInputs = [
      py.pkgs.django
      py.pkgs.pillow
    ];
    doCheck = false;
  };
  django-rest-passwordreset =
    py.pkgs.buildPythonPackage rec {
      pname = "django-rest-passwordreset";
      version = "1.5.0";
      src = fetchPypi {
        inherit version;
        pname = "django-rest-passwordreset";
        sha256 = "sha256-baON0A4M2x7VxAPma+65DxD4oac+vBP90n8rXWfRQYE=";
      };
      pyproject = true;
      build-system = [ py.pkgs.setuptools ];
    }
    // pyPkgcommonConfig;

  pname = "village_des_benjamins";
  version = "e6120174c55ed4f15ad8c5bc180e5dbecbc21045";
  src = fetchFromGitHub {
    owner = "postula";
    repo = pname;
    rev = version;
    sha256 = "sha256-z4VHQCV5Cru/ST7xU5rRnTQehSQTMOx404pTHs8/9mg=";
    #sha256 = lib.fakeSha256;
  };
  frontend = buildNpmPackage {
    inherit src;
    name = "${pname}-frontend";

    buildInputs = [
      nodejs_latest
    ];

    npmDeps = importNpmLock {
      npmRoot = src;
    };

    npmConfigHook = importNpmLock.npmConfigHook;

    installPhase = ''
      mkdir $out
      cp -r dist/* $out
    '';
  };

in
py.pkgs.buildPythonApplication rec {
  inherit src pname version;
  format = "other";

  propagatedBuildInputs = with py.pkgs; [
    beautifulsoup4
    boto3
    dj-database-url
    django
    django-better-admin-arrayfield
    django-colorfield
    django-cors-headers
    django-debug-toolbar
    django-jazzmin
    django-ordered-model
    django-silk
    django-tinymce
    djangorestframework
    djangorestframework-simplejwt
    django-rest-passwordreset
    django-storages
    openpyxl
    pillow
    psycopg2
    sentry-sdk
    whitenoise
    nh3
  ];

  nativeBuildInputs = [
    gettext
  ];

  localSettings = writeText "local_settings.py" ''
    import os

    STATIC_ROOT = os.getenv("STATIC_ROOT")
  '';

  preBuild = "${py.interpreter} -m django compilemessages -l fr";

  installPhase = ''
    mkdir -p $out/opt/vdb
    cp -r . $out/opt/vdb
    cp -r ${frontend} $out/opt/vdb/dist
    chmod +x $out/opt/vdb/manage.py
    cp ${localSettings} $out/opt/vdb/village_des_benjamins/local_settings.py
  '';

  passthru = {
    # PYTHONPATH of all dependencies used by the package
    pythonPath = py.pkgs.makePythonPath propagatedBuildInputs;

    tests = {
      inherit (nixosTests) healthchecks;
    };
  };

  meta = with lib; {
    homepage = "https://github.com/postula/village_des_benjamins";
    description = "Reservation management for the ASBL Village des benjamins";
    license = licenses.mit;
    maintainers = with maintainers; [ loispostula ];
  };
}
