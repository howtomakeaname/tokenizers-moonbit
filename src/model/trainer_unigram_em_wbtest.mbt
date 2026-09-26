// Unigram EM trainer regression battery. The inline corpus is the first 12
// non-empty lines of a wikitext-2 sample (brought in verbatim); the head
// pins were HF-0.22.2-verified at commit time (heads match HF's order to
// near-ties; the full-vocab SET agreement is ~80% — see PROGRESS for the
// measured overlap on the 2K/1K and 20K/8K configs).

///|
test "unigram EM trainer produces HF-shaped vocab" {
  let corpus : Array[String] = [
    " = Valkyria Chronicles III = ", " Senjō no Valkyria 3 : Unrecorded Chronicles ( Japanese : 戦場のヴァルキュリア3 , lit . Valkyria of the Battlefield 3 ) , commonly referred to as Valkyria Chronicles III outside Japan , is a tactical role @-@ playing video game developed by Sega and Media.Vision for the PlayStation Portable . Released in January 2011 in Japan , it is the third game in the Valkyria series . Employing the same fusion of tactical and real @-@ time gameplay as its predecessors , the story runs parallel to the first game and follows the \" Nameless \" , a penal military unit serving the nation of Gallia during the Second Europan War who perform secret black operations and are pitted against the Imperial unit \" Calamaty Raven \" . ",
    " The game began development in 2010 , carrying over a large portion of the work done on Valkyria Chronicles II . While it retained the standard features of the series , it also underwent multiple adjustments , such as making the game more forgiving for series newcomers . Character designer Raita Honjou and composer Hitoshi Sakimoto both returned from previous entries , along with Valkyria Chronicles II director Takeshi Ozawa . A large team of writers handled the script . The game 's opening theme was sung by May 'n . ",
    " It met with positive sales in Japan , and was praised by both Japanese and western critics . After release , it received downloadable content , along with an expanded edition in November of that year . It was also adapted into manga and an original video animation series . Due to low sales of Valkyria Chronicles II , Valkyria Chronicles III was not localized , but a fan translation compatible with the game 's expanded edition was released in 2014 . Media.Vision would return to the franchise with the development of Valkyria : Azure Revolution for the PlayStation 4 . ",
    " = = Gameplay = = ", " As with previous Valkyira Chronicles games , Valkyria Chronicles III is a tactical role @-@ playing game where players take control of a military unit and take part in missions against enemy forces . Stories are told through comic book @-@ like panels with animated character portraits , with characters speaking partially through voiced speech bubbles and partially through unvoiced text . The player progresses through a series of linear missions , gradually unlocked as maps that can be freely scanned through and replayed as they are unlocked . The route to each story location on the map varies depending on an individual player 's approach : when one option is selected , the other is sealed off to the player . Outside missions , the player characters rest in a camp , where units can be customized and character growth occurs . Alongside the main story missions are character @-@ specific sub missions relating to different squad members . After the game 's completion , additional episodes are unlocked , some of them having a higher difficulty than those found in the rest of the game . There are also love simulation elements related to the game 's two main heroines , although they take a very minor role . ",
    " The game 's battle system , the BliTZ system , is carried over directly from Valkyira Chronicles . During missions , players select each unit using a top @-@ down perspective of the battlefield map : once a character is selected , the player moves the character around the battlefield in third @-@ person . A character can only act once per @-@ turn , but characters can be granted multiple turns at the expense of other characters ' turns . Each character has a field and distance of movement limited by their Action Gauge . Up to nine characters can be assigned to a single mission . During gameplay , characters will call out if something happens to them , such as their health points ( HP ) getting low or being knocked out by enemy attacks . Each character has specific \" Potentials \" , skills unique to each character . They are divided into \" Personal Potential \" , which are innate skills that remain unaltered unless otherwise dictated by the story and can either help or impede a character , and \" Battle Potentials \" , which are grown throughout the game and always grant boons to a character . To learn Battle Potentials , each character has a unique \" Masters Table \" , a grid @-@ based skill table that can be used to acquire and link different skills . Characters also have Special Abilities that grant them temporary boosts on the battlefield : Kurt can activate \" Direct Command \" and move around the battlefield without depleting his Action Point gauge , the character Reila can shift into her \" Valkyria Form \" and become invincible , while Imca can target multiple enemy units with her heavy weapon . ",
    " Troops are divided into five classes : Scouts , Shocktroopers , Engineers , Lancers and Armored Soldier . Troopers can switch classes by changing their assigned weapon . Changing class does not greatly affect the stats gained while in a previous class . With victory in battle , experience points are awarded to the squad , which are distributed into five different attributes shared by the entire squad , a feature differing from early games ' method of distributing to different unit types . ",
    " = = Plot = = ", " The game takes place during the Second Europan War . Gallian Army Squad 422 , also known as \" The Nameless \" , are a penal military unit composed of criminals , foreign deserters , and military offenders whose real names are erased from the records and thereon officially referred to by numbers . Ordered by the Gallian military to perform the most dangerous missions that the Regular Army and Militia will not do , they are nevertheless up to the task , exemplified by their motto , Altaha Abilia , meaning \" Always Ready . \" The three main characters are No.7 Kurt Irving , an army officer falsely accused of treason who wishes to redeem himself ; Ace No.1 Imca , a female Darcsen heavy weapons specialist who seeks revenge against the Valkyria who destroyed her home ; and No.13 Riela Marcellis , a seemingly jinxed young woman who is unknowingly a descendant of the Valkyria . Together with their fellow squad members , these three are tasked to fight against a mysterious Imperial unit known as Calamity Raven , consisting of mostly Darcsen soldiers . ",
    " As the Nameless officially do not exist , the upper echelons of the Gallian Army exploit the concept of plausible deniability in order to send them on missions that would otherwise make Gallia lose face in the war . While at times this works to their advantage , such as a successful incursion into Imperial territory , other orders cause certain members of the 422nd great distress . One such member , Gusurg , becomes so enraged that he abandons his post and defects into the ranks of Calamity Raven , attached to the ideal of Darcsen independence proposed by their leader , Dahau . At the same time , elements within Gallian Army Command move to erase the Nameless in order to protect their own interests . Hounded by both allies and enemies , and combined with the presence of a traitor within their ranks , the 422nd desperately move to keep themselves alive while at the same time fight to help the Gallian war effort . This continues until the Nameless 's commanding officer , Ramsey Crowe , who had been kept under house arrest , is escorted to the capital city of Randgriz in order to present evidence exonerating the weary soldiers and expose the real traitor , the Gallian General that had accused Kurt of Treason . ",
    " Partly due to these events , and partly due to the major losses in manpower Gallia suffers towards the end of the war with the Empire , the Nameless are offered a formal position as a squad in the Gallian Army rather than serve as an anonymous shadow force . This is short @-@ lived , however , as following Maximilian 's defeat , Dahau and Calamity Raven move to activate an ancient Valkyrian super weapon within the Empire , kept secret by their benefactor . Without the support of Maximilian or the chance to prove themselves in the war with Gallia , it is Dahau 's last trump card in creating a new Darcsen nation . As an armed Gallian force invading the Empire just following the two nations ' cease @-@ fire would certainly wreck their newfound peace , Kurt decides to once again make his squad the Nameless , asking Crowe to list himself and all under his command as killed @-@ in @-@ action . Now owing allegiance to none other than themselves , the 422nd confronts Dahau and destroys the Valkyrian weapon . Each member then goes their separate ways in order to begin their lives anew . ",
  ]
  let m = Model::train_unigram(
    corpus,
    special_tokens=["<unk>"],
    unk_token=Some("<unk>"),
    vocab_size=Some(120),
    show_progress=false,
  )
  let vocab = m.get_vocab()
  @test.assert_eq(vocab.length(), 120)
  // invert id -> token for head checks
  let toks : Array[String?] = []
  let mut i = 0
  while i < 120 {
    toks.push(None)
    i += 1
  }
  for entry in vocab {
    if entry.1 >= 0 && entry.1 < 120 {
      toks[entry.1] = Some(entry.0)
    }
  }
  @test.assert_eq(toks[0], Some("<unk>"))
  @test.assert_eq(toks[1], Some("s"))
  @test.assert_eq(toks[2], Some("e"))
  @test.assert_eq(toks[3], Some("a"))
  @test.assert_eq(toks[4], Some("t"))
  @test.assert_eq(toks[5], Some("i"))
  @test.assert_eq(toks[6], Some("o"))
  @test.assert_eq(toks[7], Some("l"))
  @test.assert_eq(toks[8], Some("n"))
  @test.assert_eq(toks[9], Some("c"))
  @test.assert_eq(toks[10], Some("the"))
  @test.assert_eq(toks[11], Some("d"))
  // common whole-word / suffix pieces present (HF-common at this config)
  @test.assert_eq(vocab.contains("the"), true)
  @test.assert_eq(vocab.contains("e"), true)
  @test.assert_eq(vocab.contains("ing"), true)
  @test.assert_eq(vocab.contains("ed"), true)
}
