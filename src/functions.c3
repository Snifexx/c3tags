module c3tags::functions;
import std::collections;
import std::sort;
import std::io;
import ts;
import tree_sitter_c3;

const String QUERY_STR @private = `([(func_definition "fn" @fn (func_header name: (ident) @name) (attributes (attribute name: (at_ident) @attr)*)? body: (_) @body) (global_declaration (func_declaration (func_header name: (ident) @name) (attributes (attribute name: (at_ident) @attr)*)?) @spec)])`;

fn uint? query_functions(
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
    TSNode fn_name = match.captures[1].node;
    TSNode first_node_index = match.captures[0].node;
    bool is_definition = first_node_index.str_view(buf) == "fn";
    foreach (capt: match.captures[2 : match.capture_count - 2 - (int) is_definition]) {
      TSNode node = capt.node;
      String attr = node.str_view(buf);
      if (attr == "@private") continue MATCH;
    }
    uint line = ts::node_start_point(fn_name).row + 1;
    String name = fn_name.str_view(buf);
    data.mtx.lock()!;
    String signature = fn_signature(data.all, buf, match, is_definition);

    foreach (m: modules_in_this_file) {
      if (m.line_range.contains(line)) {
        String scoped_func = string::join(data.all, { m.name, "::", name }, "");
        signature = string::format(data.all, "%s => %s", m.full_name, signature);
        data.add_tag(scoped_func, tags_file_path, line, signature);
      }
    }

    data.add_tag_view(name, tags_file_path, line, signature, data.all);
    data.mtx.unlock()!;
  }
  return 0;
}

fn String fn_signature(Allocator all, char[] buf, TSQueryMatch match, bool is_definition) {
  uint start = ts::node_start_byte(match.captures[0].node);
  uint end;
  if (is_definition || match.capture_count > 2) {
    end = ts::node_start_byte(match.captures[2].node);
  } else {
    end = ts::node_end_byte(match.captures[0].node);
  }
  String[] lines = ((String)buf[start .. end - 1]).split(tmem, "\n", skip_empty: true);
  foreach (i, line: lines) {
    lines[i] = line.trim();
  }
  return string::join(mem, lines, " ");
}
