{ pkgs, system, ... }:

{
  type = "app";
  program = toString (
    pkgs.writeScriptBin "greeting-app" ''
      #!${pkgs.runtimeShell}
      echo "Hello from Nix FHS!"
      echo "This app was automatically discovered and packaged."
      echo "Current time: $(date)"
      echo "System: $(uname -a)"
      echo "Running on: ${system}"
    ''
  );
}
