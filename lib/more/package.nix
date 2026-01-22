# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Package-related utility functions
{
  lib,
  ...
}:
rec {

  # Infer the main program name from a package derivation
  # This mimics the behavior in nixpkgs where mainProgram defaults to pname
  # or the name without version suffix
  #
  # :: Derivation a -> String
  inferMainProgram =
    pkg:
    if pkg ? meta.mainProgram && pkg.meta.mainProgram != null then
      pkg.meta.mainProgram
    else if pkg ? pname && pkg.pname != null then
      pkg.pname
    else
      # Remove version suffix from name (e.g., "hello-2.10" -> "hello")
      # Use builtins.match as fallback since we might not have full lib
      let
        # Try to parse version suffix patterns like "-1.0.0", "_2.3", etc.
        parts = builtins.match "^([^-_]+)[-_]" pkg.name;
      in
      if parts != null then
        builtins.head parts
      else
        # Fallback: just return the name as-is
        pkg.name;

}
