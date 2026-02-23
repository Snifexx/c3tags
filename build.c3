module build;
import make3;
import std::os;
import std::io;

fn int main(String[] args) {
  BuildCmd cmd;
  cmd.tinit({
    "c3c", "compile-run",
    "-o", "build/c3tags",
    "src/*"
  })
  .lib_given("tree-sitter")
  .lib("tree-sitter-c3")
  .nix_env()!!;

  if (make3::@print_err(make3::@go_rebuild_urself(args))) return 1;
  if (make3::@print_err(make3::run(cmd.build()))) return 2;
	return 0;
}
