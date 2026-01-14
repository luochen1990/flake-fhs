{ pkgs }:

{
  greeting = import ./greeting { inherit pkgs; };
}
