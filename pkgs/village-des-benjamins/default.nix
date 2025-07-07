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
    self = py;
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
      # src = fetchPypi {
      #   inherit version;
      #   pname = "django_jazzmin";
      #   sha256 = "sha256-Z64Ui63kEmegnKjkNS3e+mEheV67rCOLuaZWT/hB6xs=";
      # };
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
    }
    // pyPkgcommonConfig;
  django-colorfield =
    py.pkgs.buildPythonPackage rec {
      pname = "django-colorfield";
      version = "0.14.0";
      src = fetchPypi {
        inherit version;
        pname = "django_colorfield";
        sha256 = "sha256-R429OXWojy6iqa/DJfqsoFxU6/BOyYXOEw9t6jnfuJk=";
      };
    }
    // pyPkgcommonConfig;
  django-rest-passwordreset =
    py.pkgs.buildPythonPackage rec {
      pname = "django-rest-passwordreset";
      version = "1.5.0";
      src = fetchPypi {
        inherit version;
        pname = "django-rest-passwordreset";
        sha256 = "sha256-baON0A4M2x7VxAPma+65DxD4oac+vBP90n8rXWfRQYE=";
      };
    }
    // pyPkgcommonConfig;

  pname = "village_des_benjamins";
  version = "73952ed768252a401773b6b8179b6e62f8742383";
  src = fetchFromGitHub {
    owner = "postula";
    repo = pname;
    rev = version;
    # sha256 = lib.fakeSha256;
    sha256 = "sha256-r6exr8iXGWrHO+LM2QmPGZqzPxfT2zZYK7SAFioS5vU=";
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
  # version = "3.9";
  format = "other";

  propagatedBuildInputs = with py.pkgs; [
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
    sendgrid
    sentry-sdk
    whitenoise
  ];

  nativeBuildInputs =  [
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
