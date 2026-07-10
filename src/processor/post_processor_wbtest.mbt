// PostProcessor white-box compatibility tests.

///|
test "post-processors expose HF-style configuration getters" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  let bert_alias = PostProcessor::bert_processing(
    ("[SEP]", 102),
    ("[CLS]", 101),
  )
  @test.assert_eq(bert.kind(), "BertProcessing")
  @test.assert_eq(bert_alias.to_json(), bert.to_json())
  @test.assert_eq(bert.sep(), Some(("[SEP]", 102)))
  @test.assert_eq(bert.get_sep(), Some(("[SEP]", 102)))
  @test.assert_eq(bert.cls(), Some(("[CLS]", 101)))
  @test.assert_eq(bert.get_cls(), Some(("[CLS]", 101)))
  @test.assert_eq(bert.trim_offsets(), None)
  @test.assert_eq(bert.get_trim_offsets(), None)
  @test.assert_eq(bert.get_add_prefix_space(), None)
  @test.assert_eq(bert.get_use_regex(), None)

  let roberta = PostProcessor::roberta(
    ("</s>", 2),
    ("<s>", 0),
    trim_offsets=false,
    add_prefix_space=false,
  )
  let roberta_alias = PostProcessor::roberta_processing(
    ("</s>", 2),
    ("<s>", 0),
    trim_offsets=false,
    add_prefix_space=false,
  )
  @test.assert_eq(roberta.kind(), "RobertaProcessing")
  @test.assert_eq(roberta_alias.to_json(), roberta.to_json())
  @test.assert_eq(roberta.sep(), Some(("</s>", 2)))
  @test.assert_eq(roberta.cls(), Some(("<s>", 0)))
  @test.assert_eq(roberta.trim_offsets(), Some(false))
  @test.assert_eq(roberta.get_trim_offsets(), Some(false))
  @test.assert_eq(roberta.add_prefix_space(), Some(false))
  @test.assert_eq(roberta.get_add_prefix_space(), Some(false))
  @test.assert_eq(
    PostProcessor::roberta_processing(("</s>", 2), ("<s>", 0)).to_json(),
    PostProcessor::roberta(("</s>", 2), ("<s>", 0)).to_json(),
  )
  let roberta_default = PostProcessor::roberta_processing(
    ("</s>", 2),
    ("<s>", 0),
  )
  @test.assert_eq(roberta_default.get_trim_offsets(), Some(true))
  @test.assert_eq(roberta_default.get_add_prefix_space(), Some(true))

  let bytelevel = PostProcessor::byte_level(
    add_prefix_space=false,
    trim_offsets=false,
    use_regex=false,
  )
  @test.assert_eq(bytelevel.kind(), "ByteLevel")
  @test.assert_eq(bytelevel.add_prefix_space(), Some(false))
  @test.assert_eq(bytelevel.trim_offsets(), Some(false))
  @test.assert_eq(bytelevel.use_regex(), Some(false))
  @test.assert_eq(bytelevel.get_sep(), None)
  @test.assert_eq(bytelevel.get_cls(), None)
  @test.assert_eq(bytelevel.get_add_prefix_space(), Some(false))
  @test.assert_eq(bytelevel.get_trim_offsets(), Some(false))
  @test.assert_eq(bytelevel.get_use_regex(), Some(false))

  let specials : Map[String, SpecialToken] = {}
  specials["<s>"] = SpecialToken::new("<s>", [0], ["<s>"])
  specials["</s>"] = SpecialToken::new("</s>", [1], ["</s>"])
  let template = PostProcessor::template(
    [SpecialTokenRef(id="<s>", type_id=0), SequenceRef(id="A", type_id=0)],
    [
      SpecialTokenRef(id="<s>", type_id=0),
      SequenceRef(id="A", type_id=0),
      SequenceRef(id="B", type_id=1),
      SpecialTokenRef(id="</s>", type_id=1),
    ],
    specials,
  )
  let template_alias = PostProcessor::template_processing(
    template.single_pieces(),
    template.pair_pieces(),
    template.special_tokens(),
  )
  @test.assert_eq(template.kind(), "TemplateProcessing")
  @test.assert_eq(template_alias.to_json(), template.to_json())
  @test.assert_eq(template.__len__(), 0)
  @test.assert_eq(template.get_item(0) is None, true)
  @test.assert_eq(template.single_pieces(), [
    SpecialTokenRef(id="<s>", type_id=0),
    SequenceRef(id="A", type_id=0),
  ])
  @test.assert_eq(template.get_single_pieces(), template.single_pieces())
  @test.assert_eq(PostProcessor::byte_level().get_single_pieces(), [])
  let seq_piece = SequenceRef(id="A", type_id=0)
  @test.assert_eq(seq_piece.kind(), "SequenceRef")
  @test.assert_eq(seq_piece.get_kind(), "SequenceRef")
  @test.assert_eq(seq_piece.id(), "A")
  @test.assert_eq(seq_piece.get_id(), "A")
  @test.assert_eq(seq_piece.type_id(), 0)
  @test.assert_eq(seq_piece.get_type_id(), 0)
  @test.assert_eq(seq_piece.as_tuple(), ("SequenceRef", "A", 0))
  @test.assert_eq(seq_piece.__str__(), "A")
  @test.assert_eq(
    seq_piece.__repr__(),
    "Piece(kind=\"SequenceRef\", id=\"A\", type_id=0)",
  )
  @test.assert_eq(
    SpecialTokenRef(id="a\"b\\c\n", type_id=7).__repr__(),
    "Piece(kind=\"SpecialTokenRef\", id=\"a\\\"b\\\\c\\n\", type_id=7)",
  )
  @test.assert_eq(
    Piece::from_tuple(("SpecialTokenRef", "<s>", 0)).as_tuple(),
    ("SpecialTokenRef", "<s>", 0),
  )
  let mut bad_piece = false
  try Piece::from_tuple(("Unknown", "A", 0)) |> ignore catch {
    @types.ParseError(msg) =>
      bad_piece = msg.contains("unknown template piece kind")
    _ => ()
  }
  @test.assert_eq(bad_piece, true)
  @test.assert_eq(template.single(), template.single_pieces())
  @test.assert_eq(template.get_single(), template.single())
  @test.assert_eq(template.pair_pieces().length(), 4)
  @test.assert_eq(template.get_pair_pieces(), template.pair_pieces())
  @test.assert_eq(PostProcessor::byte_level().get_pair_pieces(), [])
  @test.assert_eq(template.pair(), template.pair_pieces())
  @test.assert_eq(template.get_pair(), template.pair())
  @test.assert_eq(
    template.special_tokens().get("<s>"),
    Some(SpecialToken::new("<s>", [0], ["<s>"])),
  )
  @test.assert_eq(
    template.get_special_tokens().get("<s>"),
    Some(SpecialToken::new("<s>", [0], ["<s>"])),
  )
  @test.assert_eq(
    PostProcessor::byte_level().get_special_tokens().get("<s>"),
    None,
  )

  let seq = PostProcessor::sequence([bytelevel, bert])
  @test.assert_eq(seq.kind(), "Sequence")
  @test.assert_eq(seq.processors().map(p => p.kind()), [
    "ByteLevel", "BertProcessing",
  ])
  @test.assert_eq(seq.get_processors().map(p => p.kind()), [
    "ByteLevel", "BertProcessing",
  ])
  @test.assert_eq(seq.get_sep(), None)
  @test.assert_eq(seq.get_cls(), None)
  @test.assert_eq(seq.get_trim_offsets(), None)
  @test.assert_eq(seq.get_add_prefix_space(), None)
  @test.assert_eq(seq.get_use_regex(), None)
  @test.assert_eq(seq.__len__(), 2)
  @test.assert_eq(PostProcessor::byte_level().__len__(), 0)
  @test.assert_eq(seq.get_item(0).unwrap().kind(), "ByteLevel")
  @test.assert_eq(seq.__getitem__(1).unwrap().kind(), "BertProcessing")
  @test.assert_eq(seq.__getitem__(2) is None, true)
}

///|
test "post-processor aggregate getters return copies" {
  let specials : Map[String, SpecialToken] = {}
  specials["<multi>"] = SpecialToken::new("<multi>", [10, 11], ["<m>", "</m>"])
  let multi = specials["<multi>"]
  @test.assert_eq(multi.get_id(), "<multi>")
  @test.assert_eq(multi.id(), "<multi>")
  @test.assert_eq(multi.get_ids(), [10, 11])
  @test.assert_eq(multi.ids(), [10, 11])
  @test.assert_eq(multi.get_tokens(), ["<m>", "</m>"])
  @test.assert_eq(multi.tokens(), ["<m>", "</m>"])
  @test.assert_eq(multi.__str__(), "<multi>")
  @test.assert_eq(
    multi.__repr__(),
    "SpecialToken(id=\"<multi>\", ids=[10,11], tokens=[\"<m>\",\"</m>\"])",
  )
  @test.assert_eq(
    SpecialToken::new("a\"b\\c\n", [1], ["x\ny"]).__repr__(),
    "SpecialToken(id=\"a\\\"b\\\\c\\n\", ids=[1], tokens=[\"x\\ny\"])",
  )
  @test.assert_eq(
    SpecialToken::from_tuple(("<x>", [1, 2], ["x", "y"])).as_tuple(),
    ("<x>", [1, 2], ["x", "y"]),
  )
  let copied_ids = multi.ids()
  copied_ids.push(99)
  @test.assert_eq(multi.ids(), [10, 11])
  let copied_tokens = multi.tokens()
  copied_tokens.push("<changed>")
  @test.assert_eq(multi.tokens(), ["<m>", "</m>"])
  let template = PostProcessor::template(
    [SpecialTokenRef(id="<multi>", type_id=0)],
    [SpecialTokenRef(id="<multi>", type_id=1)],
    specials,
  )
  let single = template.single_pieces()
  single.push(SequenceRef(id="A", type_id=0))
  @test.assert_eq(template.single_pieces().length(), 1)
  let single_alias = template.single()
  single_alias.push(SequenceRef(id="B", type_id=1))
  @test.assert_eq(template.single().length(), 1)
  @test.assert_eq(PostProcessor::byte_level().single(), [])
  let string_template = PostProcessor::template_from_strings(
    "<multi>:0 $A:0", "<multi>:0 $A:0 <multi>:1 $B:1", specials,
  )
  @test.assert_eq(string_template.single(), [
    SpecialTokenRef(id="<multi>", type_id=0),
    SequenceRef(id="A", type_id=0),
  ])
  let parsed_single_alias = string_template.single()
  parsed_single_alias.push(SequenceRef(id="B", type_id=1))
  @test.assert_eq(string_template.single().length(), 2)
  let pair_alias = template.pair()
  pair_alias.push(SequenceRef(id="B", type_id=1))
  @test.assert_eq(template.pair().length(), 1)
  @test.assert_eq(PostProcessor::byte_level().pair(), [])

  let copied_specials = template.special_tokens()
  copied_specials["<multi>"] = SpecialToken::new("<multi>", [99], ["<changed>"])
  @test.assert_eq(
    template.special_tokens().get("<multi>"),
    Some(SpecialToken::new("<multi>", [10, 11], ["<m>", "</m>"])),
  )

  let seq = PostProcessor::sequence([
    PostProcessor::byte_level(),
    PostProcessor::bert(("[SEP]", 1), ("[CLS]", 2)),
  ])
  let processors = seq.processors()
  processors.push(PostProcessor::byte_level(trim_offsets=false))
  @test.assert_eq(seq.processors().length(), 2)
  let getter_processors = seq.get_processors()
  getter_processors.push(PostProcessor::byte_level(trim_offsets=false))
  @test.assert_eq(seq.get_processors().length(), 2)
}

///|
test "post-processors expose num_special_tokens_to_add alias" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  @test.assert_eq(bert.num_special_tokens_to_add(), 2)
  @test.assert_eq(bert.num_special_tokens_to_add(is_pair=true), 3)

  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  @test.assert_eq(roberta.num_special_tokens_to_add(), 2)
  @test.assert_eq(roberta.num_special_tokens_to_add(is_pair=true), 4)

  let specials : Map[String, SpecialToken] = {}
  specials["<multi>"] = SpecialToken::new("<multi>", [10, 11], ["<m>", "</m>"])
  let template = PostProcessor::template(
    [SpecialTokenRef(id="<multi>", type_id=0)],
    [SpecialTokenRef(id="<multi>", type_id=0), SequenceRef(id="B", type_id=1)],
    specials,
  )
  @test.assert_eq(template.num_special_tokens_to_add(), 2)
  @test.assert_eq(template.num_special_tokens_to_add(is_pair=true), 2)

  let seq = PostProcessor::sequence([PostProcessor::byte_level(), bert])
  @test.assert_eq(seq.num_special_tokens_to_add(is_pair=true), 3)
  @test.assert_eq(
    seq.num_special_tokens_to_add(is_pair=true),
    seq.added_tokens(pair=true),
  )
}

///|
test "post-processor process can skip special token insertion" {
  let bert = PostProcessor::bert(("[SEP]", 2), ("[CLS]", 1))
  let a = @types.Encoding::from_tokens([
    { id: 3, value: "hello", offsets: (0, 5) },
  ]).with_sequence_id(0) catch {
    _ => abort("set sequence id for a failed")
  }
  let b = @types.Encoding::from_tokens([
    { id: 4, value: "world", offsets: (0, 5) },
  ]).with_sequence_id(1) catch {
    _ => abort("set sequence id for b failed")
  }
  let pair = bert.process(a, Some(b), add_special_tokens=true)
  @test.assert_eq(pair.tokens, ["[CLS]", "hello", "[SEP]", "world", "[SEP]"])
  @test.assert_eq(pair.sequence_ids(), [None, Some(0), None, Some(1), None])
  let plain = bert.process(a, Some(b), add_special_tokens=false)
  @test.assert_eq(plain.tokens, ["hello", "world"])
  @test.assert_eq(plain.sequence_ids(), [Some(0), Some(1)])

  let specials : Map[String, SpecialToken] = {}
  specials["<s>"] = SpecialToken::new("<s>", [10], ["<s>"])
  specials["</s>"] = SpecialToken::new("</s>", [11], ["</s>"])
  let template = PostProcessor::template(
    [SpecialTokenRef(id="<s>", type_id=3), SequenceRef(id="A", type_id=2)],
    [
      SpecialTokenRef(id="<s>", type_id=3),
      SequenceRef(id="A", type_id=2),
      SequenceRef(id="B", type_id=4),
      SpecialTokenRef(id="</s>", type_id=4),
    ],
    specials,
  )
  let templated = template.process(a, Some(b), add_special_tokens=false)
  @test.assert_eq(templated.tokens, ["hello", "world"])
  @test.assert_eq(templated.type_ids, [2, 4])
  @test.assert_eq(templated.special_tokens_mask, [0, 0])
}

///|
test "post-processors expose JSON state and string aliases" {
  let specials : Map[String, SpecialToken] = {}
  specials["<s>"] = SpecialToken::new("<s>", [0], ["<s>"])
  specials["</s>"] = SpecialToken::new("</s>", [1], ["</s>"])
  let processor = PostProcessor::sequence([
    PostProcessor::byte_level(trim_offsets=false),
    PostProcessor::template(
      [SpecialTokenRef(id="<s>", type_id=0), SequenceRef(id="A", type_id=0)],
      [SequenceRef(id="A", type_id=0), SpecialTokenRef(id="</s>", type_id=1)],
      specials,
    ),
  ])
  let state = processor.__getstate__()
  @test.assert_eq(processor.__str__(), state.json)
  @test.assert_eq(processor.__repr__(), state.json)
  @test.assert_eq(
    PostProcessor::__setstate__(state).to_json(),
    processor.to_json(),
  )

  let parsed = PostProcessor::from_state(
    PostProcessorState::new(
      "{\"type\":\"RobertaProcessing\",\"sep\":[\"</s>\",2],\"cls\":[\"<s>\",0],\"trim_offsets\":false,\"add_prefix_space\":false}",
    ),
  )
  @test.assert_eq(parsed.kind(), "RobertaProcessing")
  @test.assert_eq(parsed.trim_offsets(), Some(false))
  @test.assert_eq(parsed.add_prefix_space(), Some(false))
}

///|

///|
test "PostProcessor set_trim_offsets" {
  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_trim_offsets(false)
  @test.assert_eq(roberta2.get_trim_offsets(), Some(false))

  let byte_level = PostProcessor::byte_level()
  let byte_level2 = byte_level.set_trim_offsets(false)
  @test.assert_eq(byte_level2.get_trim_offsets(), Some(false))

  // Non-matching variant returns self
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  @test.assert_eq(bert.set_trim_offsets(true).to_json(), bert.to_json())
}

///|
test "PostProcessor set_trim_offsets_alias" {
  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_trim_offsets_alias(false)
  @test.assert_eq(roberta2.get_trim_offsets(), Some(false))
}

///|
test "PostProcessor set_add_prefix_space" {
  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_add_prefix_space(false)
  @test.assert_eq(roberta2.get_add_prefix_space(), Some(false))

  let byte_level = PostProcessor::byte_level()
  let byte_level2 = byte_level.set_add_prefix_space(false)
  @test.assert_eq(byte_level2.get_add_prefix_space(), Some(false))

  // Non-matching variant returns self
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  @test.assert_eq(bert.set_add_prefix_space(true).to_json(), bert.to_json())
}

///|
test "PostProcessor set_add_prefix_space_alias" {
  let byte_level = PostProcessor::byte_level()
  let byte_level2 = byte_level.set_add_prefix_space_alias(false)
  @test.assert_eq(byte_level2.get_add_prefix_space(), Some(false))
}

///|
test "PostProcessor set_use_regex" {
  let byte_level = PostProcessor::byte_level()
  let byte_level2 = byte_level.set_use_regex(false)
  @test.assert_eq(byte_level2.get_use_regex(), Some(false))

  // Non-matching variant returns self
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  @test.assert_eq(bert.set_use_regex(true).to_json(), bert.to_json())
}

///|
test "PostProcessor set_use_regex_alias" {
  let byte_level = PostProcessor::byte_level()
  let byte_level2 = byte_level.set_use_regex_alias(false)
  @test.assert_eq(byte_level2.get_use_regex(), Some(false))
}

///|
test "PostProcessor set_sep" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  let bert2 = bert.set_sep(("[SEP]", 202))
  @test.assert_eq(bert2.get_sep(), Some(("[SEP]", 202)))

  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_sep(("[SEP]", 102))
  @test.assert_eq(roberta2.get_sep(), Some(("[SEP]", 102)))

  // Non-matching variant returns self
  let byte_level = PostProcessor::byte_level()
  @test.assert_eq(
    byte_level.set_sep(("[SEP]", 102)).to_json(),
    byte_level.to_json(),
  )
}

///|
test "PostProcessor set_sep_alias" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  let bert2 = bert.set_sep_alias(("[SEP]", 202))
  @test.assert_eq(bert2.get_sep(), Some(("[SEP]", 202)))
}

///|
test "PostProcessor set_cls" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  let bert2 = bert.set_cls(("[CLS]", 201))
  @test.assert_eq(bert2.get_cls(), Some(("[CLS]", 201)))

  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_cls(("[CLS]", 101))
  @test.assert_eq(roberta2.get_cls(), Some(("[CLS]", 101)))

  // Non-matching variant returns self
  let byte_level = PostProcessor::byte_level()
  @test.assert_eq(
    byte_level.set_cls(("[CLS]", 101)).to_json(),
    byte_level.to_json(),
  )
}

///|
test "PostProcessor set_cls_alias" {
  let roberta = PostProcessor::roberta(("</s>", 2), ("<s>", 0))
  let roberta2 = roberta.set_cls(("[CLS]", 101))
  @test.assert_eq(roberta2.get_cls(), Some(("[CLS]", 101)))
}
