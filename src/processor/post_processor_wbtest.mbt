// PostProcessor white-box compatibility tests.

///|
test "post-processors expose HF-style configuration getters" {
  let bert = PostProcessor::bert(("[SEP]", 102), ("[CLS]", 101))
  @test.assert_eq(bert.kind(), "BertProcessing")
  @test.assert_eq(bert.sep(), Some(("[SEP]", 102)))
  @test.assert_eq(bert.cls(), Some(("[CLS]", 101)))
  @test.assert_eq(bert.trim_offsets(), None)

  let roberta = PostProcessor::roberta(
    ("</s>", 2),
    ("<s>", 0),
    trim_offsets=false,
    add_prefix_space=false,
  )
  @test.assert_eq(roberta.kind(), "RobertaProcessing")
  @test.assert_eq(roberta.sep(), Some(("</s>", 2)))
  @test.assert_eq(roberta.cls(), Some(("<s>", 0)))
  @test.assert_eq(roberta.trim_offsets(), Some(false))
  @test.assert_eq(roberta.add_prefix_space(), Some(false))

  let bytelevel = PostProcessor::byte_level(
    add_prefix_space=false,
    trim_offsets=false,
    use_regex=false,
  )
  @test.assert_eq(bytelevel.kind(), "ByteLevel")
  @test.assert_eq(bytelevel.add_prefix_space(), Some(false))
  @test.assert_eq(bytelevel.trim_offsets(), Some(false))
  @test.assert_eq(bytelevel.use_regex(), Some(false))

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
  @test.assert_eq(template.kind(), "TemplateProcessing")
  @test.assert_eq(template.single_pieces(), [
    SpecialTokenRef(id="<s>", type_id=0),
    SequenceRef(id="A", type_id=0),
  ])
  @test.assert_eq(template.single(), template.single_pieces())
  @test.assert_eq(template.pair_pieces().length(), 4)
  @test.assert_eq(template.pair(), template.pair_pieces())
  @test.assert_eq(
    template.special_tokens().get("<s>"),
    Some(SpecialToken::new("<s>", [0], ["<s>"])),
  )

  let seq = PostProcessor::sequence([bytelevel, bert])
  @test.assert_eq(seq.kind(), "Sequence")
  @test.assert_eq(seq.processors().map(p => p.kind()), [
    "ByteLevel", "BertProcessing",
  ])
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
