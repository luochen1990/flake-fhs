# NOTE: 不需要在这里引入 ./options.nix
# flake-fhs 会自动通过 mkOptionsModule 单独引入 options.nix
# 这里只需要引入 config 实现文件
{
  imports = [
    ./config.nix
  ];
}
