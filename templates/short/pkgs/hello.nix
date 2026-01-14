{
  lib,
  writeShellScriptBin,
}:

writeShellScriptBin "hello-custom" ''
  echo "Hello world!"
''
