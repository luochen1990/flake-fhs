{ pkgs, ... }:

pkgs.mkShell {
  name = "python-dev";

  packages = [
    (pkgs.python3.withPackages (
      ps: with ps; [
        requests
        numpy
      ]
    ))
  ];

  shellHook = ''
    echo "🐍 Python development environment ready!"
    python3 --version
  '';
}
