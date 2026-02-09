{ writeShellScriptBin, curl }:

writeShellScriptBin "weather" ''
  ${curl}/bin/curl wttr.in
''
