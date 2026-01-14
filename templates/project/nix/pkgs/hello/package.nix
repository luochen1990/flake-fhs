{
  lib,
  writeShellScriptBin,
}:

writeShellScriptBin "hello" ''
  echo "Hello from embedded project!"
''
