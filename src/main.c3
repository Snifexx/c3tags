module c3tags;
import std::io;
import std::collections;
import ts;
import tree_sitter_c3;

fn int main(String[] args)
{
  Path p = "src/main.c3".to_tpath()!!;
  List{Path} l = {};
  l.tinit_with_array((Path[]){p});
  generate(l);
	return 0;
}

fn void generate(PathList paths) {
  // io::get_size()
  // io::is_file()
  // mem::alloc_array(Allocator allocator, $Type, usz elements)
  // File? io::open(String filename, String mode)
  // usz? File.read(&self, char[] buffer) @dynamic
  // File.close()
  bool doneOnce = false;
  TSLanguage* lang = tree_sitter_c3::language();
  foreach (path : paths) {
    //TODO report error if continue
    if (!file::is_file(path.path_string)) continue;
    usz? size = file::get_size(path.path_string);
    if (catch size) continue;
    File? f = file::open_path(path, "r");
    if (catch f) continue;
    char[] buf = mem::alloc_array(char, size + 1);
    defer free(buf);
    buf[size] = 0;
    usz? read = f.read(buf);

    TSParser* p = ts::parser_new();
    defer ts::parser_delete(p);
    ts::parser_set_language(p, lang);

    // io::print((ZString)buf);

    TSTree* tree = ts::parser_parse_string(p, null, buf, (uint) size);
    defer ts::tree_delete(tree);

    uint a;
    TSQueryError b;
    TSQuery* q = ts::query_new(
      lang,
      "(func_header name: (ident) @expr)".zstr_tcopy(),
      "(func_header name: (ident) @expr)".len,
      &a, &b
    );
    defer ts::ts_query_delete(q);

    TSQueryCursor* cursor = ts::ts_query_cursor_new();
    defer ts::ts_query_cursor_delete(cursor);
    ts::ts_query_cursor_exec(cursor, q, ts::ts_tree_root_node(tree));

    TSQueryMatch match = {};

    while (ts::ts_query_cursor_next_match(cursor, &match)) {
      TSNode node = match.captures[0].node;
      uint start = ts::ts_node_start_byte(node);
      uint end = ts::ts_node_end_byte(node);
      io::printfn("Found %s", (String)buf[start .. end - 1]);
    }
  }
}
