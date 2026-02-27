module c3tags::modules;
import std::collections;
import std::sort;
import std::io;
import ts;
import tree_sitter_c3;

const String QUERY_STR @private = `(module_declaration path: (path_ident (ident) @name) @path)`;

fn List{Module}? query_modules(TSLanguage* lang, TSTree* tree, Data* data, Path path, char[] buf, TSQueryError* error_type, uint* error_offset) {
  List{Module} modules;
  modules.tinit();
  TSQuery* query = ts::query_new(
      lang,
      QUERY_STR.zstr_tcopy(),
      QUERY_STR.len,
      error_offset, error_type);
  if (!query) return c3tags::TS_QUERY_ERROR?;
  defer ts::query_delete(query);

  TSQueryCursor* cursor = ts::query_cursor_new();
  defer ts::query_cursor_delete(cursor);
  ts::query_cursor_exec(cursor, query, ts::tree_root_node(tree));

  TSQueryMatch match = {};

  while (ts::query_cursor_next_match(cursor, &match)) {
    TSNode module_path = match.captures[0].node;
    TSNode module_name = match.captures[1].node;

    data.mtx.lock()!;
    String full_name = module_path.str_view(buf).copy(data.all);
    String name = module_name.str_view(buf);
    uint line = ts::node_start_point(module_name).row + 1;

    if (!data.modules.has_key(full_name)) {
      data.modules[full_name] = false;
      modules.push({
        .name = name,
        .full_name = full_name,
        .line_range = {.start = line},
      });
      String signature = "";
      if (full_name.contains("::")) {
        data.add_tag(full_name, path, line, "");
        signature = full_name.copy(data.all);
      }

      data.add_tag_view(name, path, line, signature, data.all);
    }
    data.mtx.unlock()!;
  }

  if (modules.len() > 0) {
    usz i = 1;
    data.mtx.lock()!;
    while (i < modules.len()) {
      uint end = modules[i].line_range.start;
      modules.get_ref(i-1).line_range.end = end;
      data.modules[modules[i-1].full_name] = true;
      i++;
    }
    modules.get_ref(i-1).line_range.end = uint.max;
    data.modules[modules[i-1].full_name] = true;
    data.mtx.unlock()!;
  }
  return modules;
}
