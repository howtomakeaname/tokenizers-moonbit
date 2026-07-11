///|
pub fn tokenizer_json_url(
  endpoint : String,
  model_id : String,
  revision : String,
) -> String {
  hub_file_url_unchecked(endpoint, model_id, revision, "tokenizer.json")
}

///|
pub fn hub_file_url(
  endpoint : String,
  model_id : String,
  revision : String,
  filename : String,
) -> String raise @types.TokenizerError {
  validate_hub_filename(filename)
  hub_file_url_unchecked(endpoint, model_id, revision, filename)
}

///|
fn hub_file_url_unchecked(
  endpoint : String,
  model_id : String,
  revision : String,
  filename : String,
) -> String {
  trim_trailing_slash(endpoint) +
  "/" +
  model_id +
  "/resolve/" +
  encode_hub_revision_segment(revision) +
  "/" +
  filename
}

///|
fn validate_hub_filename(filename : String) -> Unit raise @types.TokenizerError {
  if filename.is_empty() || filename == "." || filename == ".." {
    raise @types.ParseError("Hub filename must be a non-empty basename")
  }
  for c in filename {
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '_' ||
      c == '-'
    if !ok {
      raise @types.ParseError("Hub filename must be a basename: \{filename}")
    }
  }
}

///|
fn reject_local_files_only_direct_download(
  local_files_only : Bool,
) -> Unit raise @types.TokenizerError {
  if local_files_only {
    raise @types.ParseError(
      "Hub network request disabled because local_files_only=true",
    )
  }
}

///|
fn encode_hub_revision_segment(revision : String) -> String {
  let sb = StringBuilder::new()
  for c in revision {
    match c {
      '/' => sb.write_string("%2F")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
async fn async_download_with_redirects(
  model_id : String,
  options : HubDownloadOptions,
  plan : HubRequestPlan,
  max_redirects~ : Int,
) -> HubDownloadResult raise @types.TokenizerError {
  let mut current = plan.url
  let mut remaining = max_redirects
  let mut headers = plan.headers
  let mut retried_without_range = false
  while true {
    let (response, client) = @http.get_stream(current, headers~) catch {
      _ => raise @types.ParseError("Hub download failed: \{current}")
    }
    if is_redirect(response.code) {
      client.close()
      if remaining <= 0 {
        raise @types.ParseError(
          "Hub download exceeded redirect limit: \{plan.url}",
        )
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub redirect missing Location header: \{current}",
          )
      }
    }
    let meta = HubResponseMetadata::from_headers(
      response.code,
      response.headers,
    )
    let decision = decide_tokenizer_json_response(plan, meta)
    if decision.should_retry_without_range() && !retried_without_range {
      client.close()
      headers = headers_without_range(headers)
      current = plan.url
      remaining = max_redirects
      retried_without_range = true
      continue
    }
    let content = if decision.can_use_cache() {
      client.close()
      []
    } else {
      let chunks = read_hub_response_stream_bytes(
        client,
        current,
        options.stream_chunk_size,
      )
      client.close()
      chunks
    }
    if decision.can_use_cache() {
      return apply_tokenizer_json_download_chunks(
        model_id,
        [],
        meta,
        current,
        options~,
      )
    }
    return apply_tokenizer_json_download_bytes(
      model_id,
      content,
      meta,
      current,
      options~,
    )
  }
  raise @types.ParseError("unreachable Hub download loop")
}

///|
async fn async_download_file_with_redirects(
  options : HubDownloadOptions,
  plan : HubRequestPlan,
  max_redirects~ : Int,
) -> HubDownloadResult raise @types.TokenizerError {
  let mut current = plan.url
  let mut remaining = max_redirects
  while true {
    let (response, client) = @http.get_stream(current, headers=plan.headers) catch {
      _ => raise @types.ParseError("Hub file download failed: \{current}")
    }
    if is_redirect(response.code) {
      client.close()
      if remaining <= 0 {
        raise @types.ParseError(
          "Hub file download exceeded redirect limit: \{plan.url}",
        )
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub file redirect missing Location header: \{current}",
          )
      }
    }
    let metadata = HubResponseMetadata::from_headers(
      response.code,
      response.headers,
    )
    if metadata.status < 200 || metadata.status >= 300 {
      client.close()
      raise @types.ParseError(
        "Hub file download failed: " +
        hub_http_status_diagnostic(metadata.status),
      )
    }
    let chunks = read_hub_response_stream_bytes(
      client,
      current,
      options.stream_chunk_size,
    )
    client.close()
    let content = @utf8.decode_lossy(concat_bytes([], chunks)[:])
    return {
      content,
      resolved_revision: metadata.resolved_revision,
      etag: metadata.etag,
      final_url: current,
      status: metadata.status,
    }
  }
  raise @types.ParseError("unreachable Hub file download loop")
}

///|
async fn read_hub_response_stream_bytes(
  client : @http.Client,
  url : String,
  chunk_size : Int,
) -> Array[Bytes] raise @types.TokenizerError {
  let chunks : Array[Bytes] = []
  let max_len = positive_stream_chunk_size(chunk_size)
  while (client.read_some(max_len~) catch {
          _ =>
            raise @types.ParseError("Hub response stream read failed: \{url}")
        })
        is Some(bytes) {
    chunks.push(bytes)
  }
  if chunks.length() == 0 {
    raise @types.ParseError("Hub response body is empty: \{url}")
  }
  chunks
}

///|
async fn async_head_with_redirects(
  plan : HubRequestPlan,
  max_redirects~ : Int,
) -> HubHeadResult raise @types.TokenizerError {
  let mut current = plan.url
  let mut remaining = max_redirects
  let headers = headers_without_range(plan.headers)
  while true {
    let (client_origin, path) = split_url_for_client(current)
    let client = @http.Client(client_origin, headers~) catch {
      _ => raise @types.ParseError("Hub HEAD failed: \{current}")
    }
    let response = client..request(@http.Head, path).end_request() catch {
        _ => {
          client.close()
          raise @types.ParseError("Hub HEAD failed: \{current}")
        }
      }
    client.close()
    if is_redirect(response.code) {
      if remaining <= 0 {
        raise @types.ParseError("Hub HEAD exceeded redirect limit: \{plan.url}")
      }
      match header(response.headers, "location") {
        Some(next) => {
          current = resolve_redirect(current, next)
          remaining = remaining - 1
          continue
        }
        None =>
          raise @types.ParseError(
            "Hub HEAD redirect missing Location header: \{current}",
          )
      }
    }
    let metadata = HubResponseMetadata::from_headers(
      response.code,
      response.headers,
    )
    return {
      metadata,
      decision: decide_tokenizer_json_head_response(plan, metadata),
      final_url: current,
    }
  }
  raise @types.ParseError("unreachable Hub HEAD loop")
}

///|
fn require_response_body(
  response_body : String?,
  decision : HubResponseDecision,
) -> String raise @types.TokenizerError {
  match response_body {
    Some(body) => body
    None =>
      raise @types.ParseError(
        "Hub response body is required for cache action: " + decision.message,
      )
  }
}

///|
fn headers_without_range(headers : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = {}
  for kv in headers.to_array() {
    let key_lower = kv.0.to_lower()
    if key_lower != "range" && key_lower != "if-range" {
      out[kv.0] = kv.1
    }
  }
  out
}

///|
fn build_headers(options : HubDownloadOptions) -> Map[String, String] {
  // Keep close to HuggingFace Hub/tokenizers client requests: a tokenizers- and
  // hf_hub-flavoured User-Agent (native only), broad Accept, and optional bearer
  // token. Do not add library-specific identifiers here; the intent is to match
  // HuggingFace client traffic as closely as possible. Avoid Host/Content-Length/
  // Connection/Accept-Encoding because the HTTP runtime owns them and JS fetch
  // forbids several of these headers.
  let out : Map[String, String] = { "Accept": "*/*" }
  if user_agent_header_allowed() {
    match options.user_agent {
      Some(ua) => if !ua.is_empty() { out["User-Agent"] = ua }
      None => ()
    }
  }
  let token = match options.token {
    Some(t) => Some(t)
    None => resolve_auth_token()
  }
  match token {
    Some(t) => if !t.is_empty() { out["Authorization"] = "Bearer " + t }
    None => ()
  }
  out
}

///|
fn resolve_auth_token() -> String? {
  match @sys.get_env_var("HF_TOKEN") {
    Some(t) => if !t.is_empty() { return Some(t) }
    None => ()
  }
  match @sys.get_env_var("HF_TOKEN_PATH") {
    Some(path) =>
      if !path.is_empty() {
        match read_token_file(path) {
          Some(t) => if !t.is_empty() { return Some(t) }
          None => ()
        }
      }
    None => ()
  }
  match @sys.get_env_var("HF_HOME") {
    Some(home) =>
      if !home.is_empty() {
        match read_token_file(home + "/token") {
          Some(t) => if !t.is_empty() { return Some(t) }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
fn read_token_file(path : String) -> String? {
  let content = @fs.read_file_to_string(path) catch { _ => return None }
  Some(trim_ascii_ws(content))
}

///|
fn trim_ascii_ws(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut stop = chars.length()
  while start < stop && is_ascii_ws(chars[start]) {
    start = start + 1
  }
  while stop > start && is_ascii_ws(chars[stop - 1]) {
    stop = stop - 1
  }
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn is_ascii_ws(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn validate_hub_request(
  model_id : String,
  revision : String,
) -> Unit raise @types.TokenizerError {
  @tokenizer.Tokenizer::validate_hub_model_id(model_id)
  @tokenizer.Tokenizer::validate_hub_revision(revision)
}

///|
#cfg(target="js")
fn user_agent_header_allowed() -> Bool {
  false
}

///|
#cfg(not(target="js"))
fn user_agent_header_allowed() -> Bool {
  true
}

///|
fn header(headers : Map[String, String], name : String) -> String? {
  match headers.get(name) {
    Some(v) => return Some(v)
    None => ()
  }
  let lower = name.to_lower()
  match headers.get(lower) {
    Some(v) => return Some(v)
    None => ()
  }
  for kv in headers {
    if kv.0.to_lower() == lower {
      return Some(kv.1)
    }
  }
  None
}

///|
fn parse_non_negative_int(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for c in chars {
    let u = c.to_int()
    if u < '0'.to_int() || u > '9'.to_int() {
      return None
    }
    out = out * 10 + (u - '0'.to_int())
  }
  Some(out)
}

///|
fn parse_content_range(s : String) -> (Int?, Int?, Int?) {
  let prefix = "bytes "
  if !s.has_prefix(prefix) {
    return (None, None, None)
  }
  let chars = s.to_array()
  let rest = string_slice(chars, prefix.char_length(), chars.length())
  let rest_chars = rest.to_array()
  let slash = find_char(rest_chars, '/')
  if slash < 0 {
    return (None, None, None)
  }
  let range_text = string_slice(rest_chars, 0, slash)
  let total_text = string_slice(rest_chars, slash + 1, rest_chars.length())
  let range_chars = range_text.to_array()
  let dash = find_char(range_chars, '-')
  if dash < 0 {
    return (None, None, parse_content_range_total(total_text))
  }
  (
    parse_non_negative_int(string_slice(range_chars, 0, dash)),
    parse_non_negative_int(
      string_slice(range_chars, dash + 1, range_chars.length()),
    ),
    parse_content_range_total(total_text),
  )
}

///|
fn parse_content_range_total(s : String) -> Int? {
  if s == "*" {
    None
  } else {
    parse_non_negative_int(s)
  }
}

///|
fn find_char(chars : Array[Char], target : Char) -> Int {
  for i, c in chars {
    if c == target {
      return i
    }
  }
  -1
}

///|
fn is_redirect(code : Int) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
}

///|
fn resolve_redirect(base : String, location : String) -> String {
  if location.has_prefix("http://") || location.has_prefix("https://") {
    location
  } else if location.has_prefix("/") {
    origin(base) + location
  } else {
    parent_url(base) + "/" + location
  }
}

///|
fn origin(url : String) -> String {
  let chars = url.to_array()
  let mut slash_count = 0
  for i, c in chars {
    if c == '/' {
      slash_count = slash_count + 1
      if slash_count == 3 {
        return string_slice(chars, 0, i)
      }
    }
  }
  url
}

///|
fn split_url_for_client(
  url : String,
) -> (String, String) raise @types.TokenizerError {
  if !(url.has_prefix("http://") || url.has_prefix("https://")) {
    raise @types.ParseError(
      "Hub URL must start with http:// or https://: \{url}",
    )
  }
  let chars = url.to_array()
  let mut slash_count = 0
  for i, c in chars {
    if c == '/' {
      slash_count = slash_count + 1
      if slash_count == 3 {
        return (
          string_slice(chars, 0, i),
          string_slice(chars, i, chars.length()),
        )
      }
    }
  }
  (url, "/")
}

///|
fn parent_url(url : String) -> String {
  let chars = url.to_array()
  let mut last = -1
  for i, c in chars {
    if c == '/' {
      last = i
    }
  }
  if last <= 0 {
    url
  } else {
    string_slice(chars, 0, last)
  }
}

///|
fn trim_trailing_slash(s : String) -> String {
  let chars = s.to_array()
  let mut stop = chars.length()
  while stop > 0 && chars[stop - 1] == '/' {
    stop = stop - 1
  }
  string_slice(chars, 0, stop)
}

///|
fn string_slice(chars : Array[Char], start : Int, stop : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<stop {
    sb.write_char(chars[i])
  }
  sb.to_string()
}
