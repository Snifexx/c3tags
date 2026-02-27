module c3tags;
import std::io;
import std::collections;
import make3;
import utils;
import ts;
import tree_sitter_c3;

alias FileRange = Range{uint};

faultdef FILE_READ_ERR, TS_QUERY_ERROR;

struct Module {
  String name;
  String full_name;
  FileRange line_range;
}

struct Data {
  HashMap{String, List{TagData}} tags;
  HashMap{String, bool} modules;
  Allocator all;
}

struct TagData {
  Path file;
  String signature;
  uint line;
}

struct Tag {
  String tag;
  Path file;
  uint line;
}

fn int main(String[] args) { return utils::main_handle(args, &handled_main, 2); }

fn int? handled_main(String[] args) {
  if (args.len != 2) return 1;
  PathList l = make3::wildcard(tmem, args[1])!;

  generate(l)!;
	return 0;
}

fn void? generate(PathList paths) {
  DynamicArenaAllocator all;
  all.init(&allocator::LIBC_ALLOCATOR, 1024);
  defer all.free();
  TSLanguage* lang = tree_sitter_c3::language();

  Data data;
  data.tags.tinit(capacity: 1024);
  data.modules.tinit(capacity: 1024);
  DynamicArenaAllocator data_all;
  data_all.init(tmem, 1024);
  data.all = &data_all;

  TSParser* p = ts::parser_new();
  defer ts::parser_delete(p);
  ts::parser_set_language(p, lang);

  foreach (path : paths) {
    @pool() {
      path.path_string = path.path_string.trim();
      usz size = file::get_size(path.path_string)!;
      File f = file::open_path(path, "r")!;
      defer f.close()!!;
      char[] buf = mem::talloc_array(char, size + 1);
      buf[size] = 0;
      usz read = f.read(buf)!!; // fails only if there is no fread functionality (without libc)
      if (read > size) return FILE_READ_ERR?;

      TSTree* tree = ts::parser_parse_string(p, null, buf, (uint) size);
      defer ts::tree_delete(tree);

      TSQueryError error_type;
      uint error_offset;
      List{Module} modules_in_this_file = modules::query_modules(lang, &all, tree, &data, path, buf, &error_type, &error_offset)!;
      functions::query_functions(lang, &all, tree, &data, path, buf, modules_in_this_file, &error_type, &error_offset)!;
      types::query_types(lang, &all, tree, &data, path, buf, modules_in_this_file, &error_type, &error_offset)!;
      // TODO Maybe syntax error shouldn't outright crash!
    };
  }

  tags::generate_tags_file(data)!;
}

fn String TSNode.str_view(TSNode self, char[] buf) {
    uint start = ts::node_start_byte(self);
    uint end = ts::node_end_byte(self);
    return ((String)buf[start .. end - 1]);
}
