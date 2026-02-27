module c3tags::tags;
import std::sort;
import std::collections;
import std::hash;
import std::io;

fn bool Data.add_tag_view(Data* self, String tag, Path path, uint line, String signature, Allocator all) {
  tag = tag.copy(all);
  return self.add_tag(tag, path, line, signature);
}

fn bool Data.add_tag(Data* self, String tag, Path path, uint line, String signature) {
  TagData tag_data = {
    .file = path,
    .signature = signature,
    .line = line,
  };
  if (!self.tags.has_key(tag)) {
    List{TagData} l;
    l.init(self.all, 2);
    l.push(tag_data);
    self.tags[tag] = l;
    return true;
  }
  self.tags.get_ref(tag)!!.push(tag_data);
  return false;
}

alias Entry = Entry{String, List{TagData}};
struct EntryPair {
  String key;
  List{TagData} value;
}

fn void? generate_tags_file(Data data) {
  File f_tags = file::open("tags", "w")!;
  defer f_tags.close()!!;
  File f_c3tags = file::open("c3tags", "w")!;
  defer f_c3tags.close()!!;
  uint c3tags_line = 1;

  // Entries
	if (!data.tags.count) return;

	EntryPair[] list = allocator::alloc_array(tmem, EntryPair, data.tags.count);
	usz index = 0;
	foreach (Entry* entry : data.tags.table)
	{
		while (entry)
		{
      EntryPair pair = {
        .key = entry.key.copy(tmem),
        .value = entry.value,
      };
			list[index++] = pair;
			entry = entry.next;
		}
	}

  sort::quicksort(list, &alphabetical_order);

  foreach (entry : list) {
    String key = entry.key;
    List{TagData} value = entry.value;
    if (value.len() == 1) {
      TagData t = value[0];
      f_tags.write(string::tformat("%s\t%s\t%d\n", key, t.file, t.line))!;
    } else {
      f_tags.write(string::tformat("%s\tc3tags\tcall cursor(%d, 0)\n", key, c3tags_line))!;
      List{ushort} hashes;
      List{String} to_add;
      hashes.tinit(initial_capacity: 4);
      to_add.tinit(initial_capacity: 4);
      foreach (t: value) {
        Fnv32a hash_builder;
        hash_builder.init();
        hash_builder.update(key);
        hash_builder.update(t.file.path_string);
        ushort hash = (ushort) hash_builder;
        usz i = sort::binarysearch(hashes, hash);
        while (i < hashes.len() && hashes[i] == (ushort)hash) {
          hash_builder.update(t.file.path_string);
          hash = (ushort) hash_builder;
        } 
        hashes.push(hash);

        to_add.push(string::tformat("%s_%05d\t%s\t%d", key, hash, t.file, t.line));
        f_c3tags.write(string::tformat("%s_%05d    : %s\n", key, hash, t.signature))!;
        c3tags_line++;
      }
      f_c3tags.write("====================\n")!;
      c3tags_line++;

      sort::quicksort(to_add, &str_alphabetical_order);
      foreach (str: to_add) {
        f_tags.write(str)!;
        f_tags.write("\n")!;
      }
    }
  }
}

// TODO, add less
fn int str_alphabetical_order(String str1, String str2) {
  if (str1 == str2) return 0;
	if (!str1) return -((int) (str2.len != 0));
	if (!str2) return (int)(str1.len != 0);
	usz str1_len = str1.len;
	usz str2_len = str2.len;
	usz sz = min(str1_len, str2_len);
	for (int i = 0; i < sz; i++)
	{
		if (str1[i] != str2[i]) return str1[i] < str2[i] ? -1 : 1;
	}
  if (str1_len == str2_len) return 0;
  return sz == str1_len ? -1 : 1;
}

fn int alphabetical_order(EntryPair a, EntryPair b) {
  String str1 = a.key;
  String str2 = b.key;
  if (str1 == str2) return 0;
	if (!str1) return -((int) (str2.len != 0));
	if (!str2) return (int)(str1.len != 0);
	usz str1_len = str1.len;
	usz str2_len = str2.len;
	usz sz = min(str1_len, str2_len);
	for (int i = 0; i < sz; i++)
	{
		if (str1[i] != str2[i]) return str1[i] < str2[i] ? -1 : 1;
	}
  if (str1_len == str2_len) return 0;
  return sz == str1_len ? -1 : 1;
}
