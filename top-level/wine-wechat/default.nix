{ stdenv, lib, wine, winetricks, fetchpatch, fetchurl, gnutar, zstd, python3
, makeWrapper, srcOnly, substituteAll, runCommand, bubblewrap, coreutils, nix
, extraROMountPoints ? { }, extraMountPoints ? { }
, fakeHome ? "$HOME/.local/fakefs/wechat" }:
let
  srcHash = "0x8bs13iqwa7pi91z6kmgm7ybma1rpmxbqd3zp7h3inrm8h7ndph";
  version = "3.0.0.57-2";
  source = stdenv.mkDerivation {
    name = "source";
    phases = [ "unpackPhase" "installPhase" ];

    buildInputs = [ gnutar zstd makeWrapper ];

    src = fetchurl {
      url =
        "https://repo.archlinuxcn.org/x86_64/wine-wechat-${version}-x86_64.pkg.tar.zst";
      sha256 = srcHash;
    };
    sourceRoot = ".";

    installPhase = "cp -R . $out";
  };
  script = substituteAll {
    src = ./wechat.py;

    wineForWechat = wine.overrideAttrs (a: {
      patches = a.patches or [ ] ++ [
        (fetchpatch {
          url =
            "https://github.com/archlinuxcn/repo/raw/d86d55a4f4981a80833a7dfb1a285fcf90627f0d/archlinuxcn/wine-for-wechat/wine-wechat.patch";
          sha256 = "1akjcpfqbj2qmgx3ldd3gvzrhjp2msac7mm34lwj1mmbzd9galzy";
        })
      ];
    });
    winetricksForWechat = winetricks.override { inherit wine; };
    inherit gnutar python3;
    expectedHash = srcHash;
    tarball = "${source}/opt/wine-wechat/wine-wechat.tar.zst";

    postInstall = ''
      chmod +x $out
    '';
  };

  makeBindOption = option: mountPoints:
    lib.concatStringsSep " "
    (lib.mapAttrsToList (k: v: "${option} ${k} ${v}") mountPoints);
  mountPoints = "(${makeBindOption "--ro-bind" extraROMountPoints} ${
      makeBindOption "--bind" extraMountPoints
    })";

in runCommand "wechat" {
  inherit bubblewrap coreutils nix script mountPoints fakeHome;
  inherit (stdenv) shell;
  buildInputs = [ makeWrapper ];
  exportReferencesGraph = [ "scriptRefs" script "zstdRefs" zstd ];
  meta.license = stdenv.lib.licenses.unfree;
} ''
  mkdir -p $out/bin
  cp -r --no-preserve=all ${source}/usr/share $out
  substituteAll ${./bwrap.sh} $out/bin/wechat
  chmod +x $out/bin/wechat
  wrapProgram $out/bin/wechat --prefix PATH : ${lib.makeBinPath [ zstd ]}

  mkdir -p $out/share/wechat
  cat scriptRefs zstdRefs|grep '^/'|sort|uniq > $out/share/wechat/nix-closure
''
