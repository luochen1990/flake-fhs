# 这是本项目的 lib 引用
lib:
let
  inherit (builtins)
    head;

  inherit (lib)
    filter
    for
    unionFor
    findFiles
    hasPostfix
    isNonEmptyDir
    ;
in
{
  # utils preparation tool function
  prepareLib =
    {
      roots,
      lib, # 这是待准备的项目的 lib
      pkgs ? null,
    }:
    let
     # TODO: 支持多 root
      path = head (filter isNonEmptyDir (for roots (root: root + "/utils")));

      # 返回（不依赖pkgs的）自定义函数集合，但每个自定义函数都可从 lib 参数中访问（不依赖pkgs的）基础工具函数
      lv1 = unionFor (findFiles (hasPostfix "nix") path) (p: import p layer1);
      layer1 = lv1 // lib; # TODO: 命名冲突不覆盖，而是直接报错

      # 返回（依赖pkgs的）自定义函数集合，但每个自定义函数都可从 lib 参数中访问全量工具函数
      lv2 =
        pkgs:
        let
          myLib = layer2 pkgs; # 提前预备，避免循环中重复创建
        in
        if isNonEmptyDir (path + "/more") then
          unionFor (findFiles (hasPostfix "nix") (path + "/more")) (
            p:
            import p (
              # lib/more/ 目录下的文件可以从 pkgs.lib 参数中访问所有函数
              pkgs // { lib = myLib;}
            )
          )
        else
          { };
      layer2 = pkgs: lv2 pkgs // layer1; # TODO: 命名冲突不覆盖，而是直接报错
    in
    # 用户从 prepareLib { ... } 获得的
    # 根据是否给了 pkgs 有所区别: 如果给了 pkgs 则返回全量函数集合；
    # 若没有 pkgs 则返回基础函数集合 以及附带 more 用于加载全量函数集合
    if pkgs != null then layer2 pkgs else { more = pkgs: layer2 pkgs; } // layer1;
}
