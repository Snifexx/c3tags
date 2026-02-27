module c3tags::types;
import std::io;
import std::collections;
import ts;
import tree_sitter_c3;

const String QUERY_STR @private = `[
(struct_declaration name: (type_ident) @name (attributes (attribute name: (at_ident) @attr)*)?)
(typedef_declaration name: (type_ident) @name (attributes (attribute name: (at_ident) @attr)*)?)
(alias_declaration name: (type_ident) @name (attributes (attribute name: (at_ident) @attr)*)?)
]`;

fn uint? query_types(
  TSLanguage* lang, Allocator all, TSTree* tree, Data* data,
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
    assert(match.capture_count >= 1);
    TSNode type_name = match.captures[0].node;
    foreach (capt: match.captures[1 : match.capture_count - 1]) {
      TSNode node = capt.node;
      String attr = node.str_view(buf);
      if (attr == "@private") continue MATCH;
    }

    uint line = ts::node_start_point(type_name).row + 1;
    String name = type_name.str_view(buf);
    String signature = "";

    foreach (m: modules_in_this_file) {
      if (m.line_range.contains(line)) {
        String scoped_type = string::join(all, { m.name, "::", name }, "");
        signature = string::format(all, "in module %s", m.full_name);
        data.add_tag(scoped_type, tags_file_path, line, signature);
      }
    }

    data.add_tag_view(name, tags_file_path, line, signature, all);
  }
  return 0;
}
