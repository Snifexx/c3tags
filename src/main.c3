module c3tags;
import std::io;
import std::collections;
import std::thread;
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
  Mutex mtx;
  uint processed;
  ConditionVariable cond_var;
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
  TSLanguage* lang = tree_sitter_c3::language();

  Data data;
  data.tags.tinit(capacity: 1024);
  data.modules.tinit(capacity: 1024);
  DynamicArenaAllocator data_all;
  data_all.init(tmem, 1024);
  data.all = &data_all;
  defer data_all.free();
  data.mtx.init()!;
  defer data.mtx.destroy()!!;
  data.processed = (uint) paths.len();
  data.cond_var.init()!;
  defer data.cond_var.destroy()!!;


  FixedThreadPool pool;
  pool.init((paths.len()/32) + 1)!;

  foreach (i, path : paths) {
    //uint i, Path path, TSParser* p, Mutex p_mtx, TSLanguage* lang, Data* data
    pool.push(&process_file, (uint) i, path, lang, &data)!;
  }

  data.mtx.lock()!;
  while (data.processed > 0) data.cond_var.wait(&data.mtx)!;
  data.mtx.unlock()!;

  pool.destroy()!;
  tags::generate_tags_file(data)!;
}

fn void process_file(any[] args) {
  char[1024*1024] buf;
  OnStackAllocator all;
  all.init(&buf, &allocator::LIBC_ALLOCATOR);


  mem::@pool_init(&all, 1024) {
    uint i = *anycast(args[0], uint)!!;
    Path path = *anycast(args[1], Path)!!;
    TSLanguage* lang = *anycast(args[2], TSLanguage*)!!;
    Data* data = *anycast(args[3], Data*)!!;

    if (catch err = handled_process_file(path, lang, data)) {
      io::eprintfn("ERROR IN THREAD %d FOR FILE '%s'", i, path.path_string.trim());
      io::eprintn(err);
    }
    data.mtx.lock()!!;
    data.processed--;
    data.cond_var.signal()!!;
    data.mtx.unlock()!!;
  };
}
//alias ThreadPoolFn = fn void(any[] args);
fn void? handled_process_file(Path path, TSLanguage* lang, Data* data) {
  path.path_string = path.path_string.trim();
  usz size = file::get_size(path.path_string)!;
  File f = file::open_path(path, "r")!;
  defer f.close()!!;
  char[] buf = mem::talloc_array(char, size + 1);
  buf[size] = 0;
  usz read = f.read(buf)!!; // fails only if there is no fread functionality (without libc)
  if (read > size) return FILE_READ_ERR?;

  TSParser* p = ts::parser_new();
  defer ts::parser_delete(p);
  ts::parser_set_language(p, lang);

  TSTree* tree = ts::parser_parse_string(p, null, buf, (uint) size);
  defer ts::tree_delete(tree);

  TSQueryError error_type;
  uint error_offset;
  List{Module} modules_in_this_file = modules::query_modules(lang, tree, data, path, buf, &error_type, &error_offset)!;
  functions::query_functions(lang, tree, data, path, buf, modules_in_this_file, &error_type, &error_offset)!;
  types::query_types(lang, tree, data, path, buf, modules_in_this_file, &error_type, &error_offset)!;
  // TODO Maybe syntax error shouldn't outright crash!
}

fn String TSNode.str_view(TSNode self, char[] buf) {
    uint start = ts::node_start_byte(self);
    uint end = ts::node_end_byte(self);
    return ((String)buf[start .. end - 1]);
}
