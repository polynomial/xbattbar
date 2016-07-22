{ nixpkgs ? import <nixpkgs> {}, compiler ? "default" }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, base, old-time, select, stdenv, X11 }:
      mkDerivation {
        pname = "xbattbar";
        version = "0.2";
        src = ./.;
        isLibrary = false;
        isExecutable = true;
        executableHaskellDepends = [ base old-time select X11 ];
        homepage = "https://github.com/polachok/xbattbar";
        description = "Simple battery indicator";
        license = stdenv.lib.licenses.mit;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  drv = haskellPackages.callPackage f {};

in

  if pkgs.lib.inNixShell then drv.env else drv
