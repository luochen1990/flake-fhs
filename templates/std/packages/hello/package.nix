{
  lib,
  writeShellScriptBin,
}:

writeShellScriptBin "hello-fhs" ''
  echo "Hello from Nix FHS package hello-fhs-1.0.0!"
''
