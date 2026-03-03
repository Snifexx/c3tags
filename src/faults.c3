module c3tags::faults;
import std::io;
import std::collections;
import ts;
import tree_sitter_c3;

const String QUERY_STR @private = `(faultdef_declaration) @faults`;

fn uint? query_faults(
  TSLanguage* lang, TSTree* tree, Data* data,
  Path tags_file_path, char[] buf, List{Module} modules_in_this_file, TSQueryError* error_type,  uint* err_offset
) {
  // TODO Error Handling in queries

  TSQuery* query = ts::query_new(
      lang,
      QUERY_STR.zstr_tcopy(),
      QUERY_STR.len,
      err_offset, error_type);
  if (!query) return c3tags::TS_QUERY_ERROR?;
  defer ts::query_delete(query);

  TSQueryCursor* cursor = ts::query_cursor_new();
  defer ts::query_cursor_delete(cursor);
  ts::query_cursor_exec(cursor, query, ts::tree_root_node(tree));

  TSQueryMatch match = {};

  while MATCH: (ts::query_cursor_next_match(cursor, &match)) {
    assert(match.capture_count == 1);
    TSNode fault_def = match.captures[0].node;
    TSTreeCursor logic = ts::tree_cursor_new(fault_def);
    defer ts::tree_cursor_delete(&logic);
    if (!ts::tree_cursor_goto_first_child(&logic)) return c3tags::PARSE_ERR?;
    do {
      TSNode curr = ts::tree_cursor_current_node(&logic);
      if (!ts::node_is_named(curr) || (ZString)ts::node_type(curr) != "const_ident") continue;
      if (ts::tree_cursor_goto_next_sibling(&logic) && (ZString)ts::node_type(ts::tree_cursor_current_node(&logic)) == "attributes") {
        if (!ts::tree_cursor_goto_first_child(&logic)) return c3tags::PARSE_ERR?;
        do {
          TSNode attrs = ts::tree_cursor_current_node(&logic);
          if (attrs.str_view(buf) == "@private") continue MATCH;
        } while (ts::tree_cursor_goto_next_sibling(&logic));
      }

      uint line = ts::node_start_point(curr).row + 1;
      String name = curr.str_view(buf);
      String signature = "";

      data.mtx.lock()!;
      foreach (m: modules_in_this_file) {
        if (m.line_range.contains(line)) {
          String scoped_type = string::join(data.all, { m.name, "::", name }, "");
          signature = string::format(data.all, "in module %s", m.full_name);
          data.add_tag(scoped_type, tags_file_path, line, signature);
        }
      }

      data.add_tag_view(name, tags_file_path, line, signature, data.all);
      data.mtx.unlock()!;
    } while (ts::tree_cursor_goto_next_sibling(&logic));
  }
  return 0;
}
