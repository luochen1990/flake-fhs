{ pkgs, ... }:

pkgs.mkShell {
  name = "python-env";

  packages = [
    (pkgs.python3.withPackages (
      ps: with ps; [
        requests
      ]
    ))
  ];

  shellHook = ''
    echo "Python environment loaded!"
  '';
}
