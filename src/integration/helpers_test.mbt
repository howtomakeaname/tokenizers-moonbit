// Shared helpers for fixture-backed integration tests. All helpers keep the
// existing self-skip behavior when optional tests/data fixtures are absent.

///|
fn load_text(path : String) -> String? {
  if @fs.path_exists(path) {
    Some(@fs.read_file_to_string(path)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
fn parse_int_array(obj : Map[String, Json], key : String) -> Array[Int] {
  let out : Array[Int] = []
  match obj.get(key) {
    Some(Array(a)) =>
      for x in a {
        match x {
          Number(n, ..) => out.push(n.to_int())
          _ => ()
        }
      }
    _ => ()
  }
  out
}

