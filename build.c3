module build;
import std::os;
import std::io;
import make3;
import utils;

fn int main(String[] args) {
  DynamicArenaAllocator all;
  all.init(&allocator::LIBC_ALLOCATOR, 1024);
  defer all.free();
  BuildCmd cmd;
  cmd.tinit({
    "c3c", "compile-run",
    "-o", "build/c3tags",
    "src/*", "make3.c3"
  })
  .lib_given("tree-sitter")
  .lib("tree-sitter-c3")
  .nix_env()!!;
  // cmd.args.add_array({"--", "./test/test.txt"});
  // cmd.args.add_array({"--", "libs/**/*.c3i"});
  // cmd.args.add_array({"--", "make3.c3 src/**/*.c3 libs/**/*.c3i"});
  cmd.args.add_array({"--", "make3.c3 src/**/*.c3 libs/**/*.c3i $(dirname (which c3c))/../lib/c3/std/**/*.c3" });
  // cmd.args.add_array(make3::wildcard(&all,)!!.to_targs());

  if (utils::@print_err(make3::@go_rebuild_urself(args))) return 1;

  String arg = args.len > 1 ? args[1] : "";
  switch (arg) {
    case "test":
      if (utils::@print_err(make3::default_tests("test", {"make3.c3"}))) return 2;
      break;
    default:
      if (utils::@print_err(make3::run(cmd.build()))) return 2;
  }
	return 0;
}
