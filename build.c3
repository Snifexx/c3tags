module build;
import std::os;
import std::io;
import make3;
import utils;

//
// NOTE! You need to provide the tree-sitter lib.so!
//
// If you're also using nix and the nix flake shell you can uncomment the `.nix_env()` line.
// Otherwise provide the file directly and use `.lib("tree-sitter")` instead of `.lib_given("tree-sitter")`
//

fn int main(String[] args) {
  DynamicArenaAllocator all;
  all.init(&allocator::LIBC_ALLOCATOR, 1024);
  defer all.free();
  BuildCmd cmd;
  cmd.tinit({
    "c3c", "compile",
    "-o", "build/c3tags",
    "src/*", "make3.c3"
  })
  .lib_given("tree-sitter")
  .lib("tree-sitter-c3")
  // .nix_env()
  !!;

  if (utils::@catch_print(make3::@go_rebuild_urself(args))) return 1;

  String arg = args.len > 1 ? args[1] : "";
  switch (arg) {
    case "test":
      if (utils::@catch_print(make3::default_tests("test", {"make3.c3"}))) return 2;
    case "clear":
      cmd.args[1] = "compile-run";
      cmd.args.add_array({"--", "clear"});
      if (utils::@catch_print(make3::run(cmd.build()))) return 2;
    case "run":
      cmd.args[1] = "compile-run";
      if (args.len > 2) {
        cmd.args.push("--");
        cmd.args.add_array(args[2..]);
      } 
      if (utils::@catch_print(make3::run(cmd.build()))) return 2;
    default:
      if (utils::@catch_print(make3::run(cmd.build()))) return 2;
  }
	return 0;
}
