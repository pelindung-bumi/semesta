{ fetchurl, lib, stdenvNoCC }:
stdenvNoCC.mkDerivation rec {
  pname = "k3s";
  version = "1.35.1+k3s1";

  src = fetchurl {
    url = "https://github.com/k3s-io/k3s/releases/download/v1.35.1%2Bk3s1/k3s";
    sha256 = "1gxbcghkl17d4lvk94r55q4gw5an52lr0p36nix78gb78xpcl1p4";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/k3s"
  '';

  meta = {
    description = "Lightweight Kubernetes binary release from upstream k3s";
    homepage = "https://k3s.io/";
    license = lib.licenses.asl20;
    mainProgram = "k3s";
    platforms = [ "x86_64-linux" ];
  };
}
