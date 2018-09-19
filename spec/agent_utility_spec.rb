# encoding: utf-8
require_relative "./spec_helper"

describe "Utility functions to handle names of people" do
  before(:all) do
    @utility = Bloodhound::AgentUtility
  end

  it "should reject a name that has 'Canadian Museum of Nature'" do
    input = "Jeff Saarela; Canadian Museum of Nature"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(["Jeff", "Saarela"])
    expect(@utility.clean(parsed[1]).to_h).to eq({given: nil, family:nil})
  end

  it "should reject a name that has 'Department' in it" do
    input = "Oregon Department of Agriculture"
    parsed = @utility.parse(input)
    expect(@utility.clean(parsed[0]).to_h).to eq({given: nil, family:nil})
  end

  it "should capitalize mistaken lowercase first initials" do
    input = "r.C. Smith"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:particle, :given, :family)).to eq(["r.C.", nil, "Smith"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given:"R.C.", family:"Smith"})
  end

  it "should clean family names with extraneous period" do
    input = "C. Tanner."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.', 'Tanner.'])
    expect(@utility.clean(parsed[0]).to_h).to eq({given:'C.', family: 'Tanner'})
  end

  it "should recognize a single name in reverse order with a comma" do
    input = "Tanner, C.A."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.A.', 'Tanner'])
    expect(@utility.clean(parsed[0]).to_h).to eq({given:'C.A.', family: 'Tanner'})
  end

  it "should recognize a single name as a family name" do
    input = "Tanner"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Tanner', nil]) #expect this because parser doesn't get it right
    expect(@utility.clean(parsed[0]).to_h).to eq({given:nil, family: 'Tanner'})
  end

  it "should remove numerical values and lowercase letter" do
    input = "23440a Ian D. MacDonald"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Ian D.", "MacDonald"])
  end

  it "should remove 'male' or 'female' text from name" do
    input = "13267 (male) W.J. Cody; 13268 (female) W.E. Kemp"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(["W.J.", "Cody"])
    expect(parsed[1].values_at(:given, :family)).to eq(["W.E.", "Kemp"])
  end

  it "should remove numerical values and capital letter" do
    input = "23440G Ian D. MacDonald"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Ian D.", "MacDonald"])
  end

  it "should remove numerical values and lowercase letter in brackets" do
    input = "23440(a) Ian D. MacDonald"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Ian D.", "MacDonald"])
  end

  it "should normalize a name all in caps" do
    input = "WILLIAM BEEBE"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["WILLIAM", "BEEBE"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: 'William', family:'Beebe'})
  end

  it "should normalize a name all in caps, written in reverse order" do
    input = "SOSIAK, MACLENNAN"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["MACLENNAN", "SOSIAK"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: 'MacLennan', family:'Sosiak'})
  end

  #TODO Latin American names not parsed properly when Namae.options[:prefer_comma_as_separator] = true
#  it "should deal with composite family names" do
#    input = "Rázuri Gonzales, Ernesto"
#    parsed = @utility.parse(input)
#    expect(parsed.size).to eq(1)
#    expect(parsed[0].values_at(:given, :family)).to eq(["Ernesto", "Rázuri Gonzales"])
#    expect(@utility.clean(parsed[0]).to_h).to eq({given: 'Ernesto', family:'Rázuri Gonzales'})
#  end

  it "should remove 'et al'" do
    input = "Jack Smith et al"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove '; et al'" do
    input = "Jack Smith; et al"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove 'et al.'" do
    input = "Jack Smith et al."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove Collector(s):" do
    input = "Collector(s): Richard D. Worthington"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Richard D.', 'Worthington'])
  end

  it "should remove 'and others'" do
    input = "Jack Smith and others"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove '& others'" do
    input = "Jack Smith & others"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should separate a concatenated name" do
    input = "J.R.Smith"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['J.R.', 'Smith'])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: 'J.R.', family:'Smith'})
  end

  it "should separate multiple concatenated names" do
    input = "J.R.Smith and P.Sutherland"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['J.R.', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['P.', 'Sutherland'])
  end

  it "should properly deal with Rev." do
    input = "Rev. Jack Smith"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should properly deal with Fr." do
    input = "Fr. Jack Smith"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should properly deal with Miss" do
    input = "Miss Penelope Cruz"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Penelope', 'Cruz'])
  end

  it "should properly deal with Mrs." do
    input = "Mrs. Penelope Cruz"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Penelope', 'Cruz'])
  end

  it "should properly deal with Ms" do
    input = "Ms Penelope Cruz"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Penelope', 'Cruz'])
  end

  it "should remove 'etc'" do
    input = "Jack Smith etc"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove 'etc.'" do
    input = "Jack Smith etc."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove ', YYYY' " do
    input = "Jack Smith, 2009"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should remove brackets from name" do
    input = "W.P. Coreneuk(?)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['W.P.', 'Coreneuk'])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: 'W.P.', family:'Coreneuk'})
  end

  it "should remove 'Game Dept.'" do
    input = "Game Dept.  prep. C.J. Guiguet"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.J.', 'Guiguet'])
  end

  it "should explode by 'prep. by' at the start of the string" do
    input = "prep. C.J. Guiguet"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.J.', 'Guiguet'])
  end
  
  it "should explode by 'prep. by' at the start of the string" do
    input = "prep. by C.J. Guiguet"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.J.', 'Guiguet'])
  end

  it "should strip out 'prep.' at the end of the string" do
    input = "B. Pfeiffer prep."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['B.', 'Pfeiffer'])
  end

  it "should explode by 'prep'" do
    input = "R.H. Mackay  prep. I. McTaggart-Cowan"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['R.H.', 'Mackay'])
  end

  it "should explode by 'via" do
    input = "via Serena Lowartz"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Serena', 'Lowartz'])
  end

  it "should explode by +" do
    input = "D.B. Jepsen + T. L. McGuire"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['D.B.', 'Jepsen'])
  end

  it "should explode by 'stet!'" do
    input = "Jack Smith stet!"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should explode by 'stet'" do
    input = "Jack Smith stet 1989"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should explode by 'stet,'" do
    input = "Jack Smith stet, 1989"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
  end

  it "should explode by 'e'" do
    input = "Jack Smith e Carlos Santos"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Carlos', 'Santos'])
  end

  it "should not explode by E" do
    input = "Jack E Smith"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack E', 'Smith'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Smith", given: "Jack E."})
  end

  it "should remove 'UNKNOWN'" do
    input = "UNKNOWN"
    parsed = @utility.parse(input)
    expect(parsed).to eq([])
  end

  it "should remove 'importer'" do
    input = "Lucanus, O. (importer)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['O.', 'Lucanus'])
  end

  it "should not parse what does not resemble a name" do
    input = "EB"
    parsed = @utility.parse(input)
    expect(parsed).to eq([])
  end

  it "should remove extraneous material" do
    input = "Unknown [J. S. Erskine?]"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['J. S.', 'Erskine'])
  end

  it "should remove [no data]" do
    input = "[no data]"
    parsed = @utility.parse(input)
    expect(parsed).to eq([])
  end

  it "should remove [no disponible]" do
    input = "[no disponible]"
    parsed = @utility.parse(input)
    expect(parsed).to eq([])
  end
  
  it "should parse name with many given initials" do
    input = "FAH Sperling"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['FAH', 'Sperling'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Sperling", given: "F.A.H."})
  end

  it "should preserve caps in family names" do
    input = "Chris MacQuarrie"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Chris', 'MacQuarrie'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "MacQuarrie", given: "Chris"})
  end

  it "should remove more exteneous material" do
    input = "Jack [John]: Smith12345"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack John', 'Smith'])
  end

  it "should explode names with '/'" do
    input = "O.Bennedict/G.J. Spencer"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['O.', 'Bennedict'])
    expect(parsed[1].values_at(:given, :family)).to eq(['G.J.', 'Spencer'])
  end

  it "should explode names with ' - '" do
    input = "Jack Smith - Yves St-Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'St-Archambault'])
  end

  it "should explode names with ' – '" do
    input = "Jack Smith   –   Yves St-Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'St-Archambault'])
  end

  it "should explode names with 'and'" do
    input = "Jack Smith and Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'or'" do
    input = "Jack Smithor or Orlando Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smithor'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Orlando', 'Archambault'])
  end

  it "should explode names with 'AND'" do
    input = "Jack Smith AND Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode multiple names with 'and'" do
    input = "Jack Smith and Yves Archambault and Don Johnson"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
    expect(parsed[2].values_at(:given, :family)).to eq(['Don', 'Johnson'])
  end

  it "should explode names with ';'" do
    input = "Jack Smith; Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with spaces" do
    input = "Puttock, C.F. James, S.A."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.F.', 'Puttock'])
    expect(parsed[1].values_at(:given, :family)).to eq(['S.A.', 'James'])
  end

  it "should explode names with ' | '" do
    input = "Jack Smith | Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with '|'" do
    input = "Jack Smith|Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with '&'" do
    input = "Jack Smith & Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode lists of names that contain ',' and '&'" do
    input = "V. Crecco, J. Savage & T.A. Wheeler"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['V.', 'Crecco'])
    expect(parsed[1].values_at(:given, :family)).to eq(['J.', 'Savage'])
    expect(parsed[2].values_at(:given, :family)).to eq(['T.A.', 'Wheeler'])
  end

  it "should explode lists of names with initials (reversed), commas, and '&'" do
    input = "Harkness, W.J.K., Dickinson, J.C., & Marshall, N."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['W.J.K.', 'Harkness'])
    expect(parsed[1].values_at(:given, :family)).to eq(['J.C.', 'Dickinson'])
    expect(parsed[2].values_at(:given, :family)).to eq(['N.', 'Marshall'])
  end

  it "should explode lists of names with semicolons and commas in reverse order" do
    input = "Gad., L.; Dawson, J.; Wyatt, N.; Gerring, J."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(4)
    expect(parsed[0].values_at(:given, :family)).to eq(['L.', 'Gad.'])
    expect(parsed[1].values_at(:given, :family)).to eq(['J.', 'Dawson'])
    expect(parsed[2].values_at(:given, :family)).to eq(['N.', 'Wyatt'])
    expect(parsed[3].values_at(:given, :family)).to eq(['J.', 'Gerring'])
  end

  it "should explode lists of names with initials (forward), commas and '&'" do
    input = "N. Lujan, D. Werneke, D. Taphorn, D. German & D. Osorio"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(5)
    expect(parsed[0].values_at(:given, :family)).to eq(['N.', 'Lujan'])
    expect(parsed[1].values_at(:given, :family)).to eq(['D.', 'Werneke'])
    expect(parsed[2].values_at(:given, :family)).to eq(['D.', 'Taphorn'])
    expect(parsed[3].values_at(:given, :family)).to eq(['D.', 'German'])
    expect(parsed[4].values_at(:given, :family)).to eq(['D.', 'Osorio'])
  end

  it "should explode names with '/'" do
    input = "Jack Smith / Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'et'" do
    input = "Jack Smith et Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'with'" do
    input = "Jack Smith with Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'with' and 'and'" do
    input = "Jack Smith with Yves Archambault and Don Johnson"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
    expect(parsed[2].values_at(:given, :family)).to eq(['Don', 'Johnson'])
  end

  it "should explode names with 'by'" do
    input = "by P. Zika"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['P.', 'Zika'])
  end

  it "should explode names with 'annotated'" do
    input = "annotated Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'annotated by'" do
    input = "annotated by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'conf'" do
    input = "Jack Johnson conf Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'conf'" do
    input = "Jack Johnson conf Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'conf.'" do
    input = "Jack Johnson conf. Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'conf by'" do
    input = "Jack Johnson conf by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'conf. by'" do
    input = "Jack Johnson conf. by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'confirmed by'" do
    input = "Jack Johnson confirmed by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'checked:'" do
    input = "C.E. Garton 1980 checked:W.G. Argus 1980"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.E.', 'Garton'])
    expect(parsed[1].values_at(:given, :family)).to eq(['W.G.', 'Argus'])
  end

  it "should explode names with 'checked by'" do
    input = "Jack Johnson checked by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'Checked By'" do
    input = "Checked By Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'dupl'" do
    input = "Jack Johnson dupl Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'dupl.'" do
    input = "Jack Johnson dupl. Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'dup by'" do
    input = "Jack Johnson dup by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'dup. by'" do
    input = "Jack Johnson dup. by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'ex. by'" do
    input = "Rex Johnson ex. by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'ex by'" do
    input = "Rex Byron ex by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'examined by'" do
    input = "Rex Byron examined by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'in part'" do
    input = "Rex Byron in part Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'in part by'" do
    input = "Rex Byron in part by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'redet by'" do
    input = "Jack Smith redet. by Michael Jackson"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'Smith'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Michael', 'Jackson'])
  end

  it "should explode names with 'stet'" do
    input = "Anna Roberts stet R. Scagel 1981"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Anna', 'Roberts'])
    expect(parsed[1].values_at(:given, :family)).to eq(['R.', 'Scagel'])
  end

  it "should explode names with 'ver by'" do
    input = "Rex Byron ver by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'ver. by'" do
    input = "Rex Byron ver. by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with 'verified by'" do
    input = "Rex Byron verified by Yves Archambault"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Rex', 'Byron'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Yves', 'Archambault'])
  end

  it "should explode names with abbreviation for verified by" do
    input = "W.W. Diehl; Verif.: C.L. Shear"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['W.W.', 'Diehl'])
    expect(parsed[1].values_at(:given, :family)).to eq(['C.L.', 'Shear'])
  end

  it "should explode names with verified indicator in French" do
    input = "Vérifié Michelle Garneau"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Michelle', 'Garneau'])
  end

  it "should explode names with complex verif. statements with year" do
    input = "Gji; Verif. S. Churchill; 1980"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Gji', nil])
    expect(parsed[1].values_at(:given, :family)).to eq(['S.', 'Churchill'])
  end

  it "should remove FNA" do
    input = "Adam F. Szczawinski ; J.K. Morton (FNA) 1993"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Adam F.', 'Szczawinski'])
    expect(parsed[1].values_at(:given, :family)).to eq(['J.K.', 'Morton'])
  end

  it "should remove Roman numerals from dates" do
    input = "S. Ross 12/i/1999"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['S.', 'Ross'])
  end

  it "should remove Roman numerals from determinations" do
    input = "S. Ross III.1990"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['S.', 'Ross'])
  end

  it "should not remove Roman numeral-like text from names" do
    input = "Xinxiao Wang"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Xinxiao', 'Wang'])
  end

  it "should deal with 'Ver By'" do
    input = "S. Ross Ver By P. Perrin"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['S.', 'Ross'])
    expect(parsed[1].values_at(:given, :family)).to eq(['P.', 'Perrin'])
  end

  it "should recognize a religious suffix like Marie-Victorin, frère" do
    input = "Marie-Victorin, frère"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['Marie-Victorin', nil])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Marie-Victorin", given: nil})
  end

  it "should remove (See Note Inside)" do
    input = "J. Macoun (See Note Inside)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['J.', 'Macoun'])
  end

  it "should remove nom. rev." do
    input = "Bird,C.J. 9/Mar/1981: nom. rev."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.J.', 'Bird'])
  end

  it "should remove stet ! at the end of the name" do
    input = "Roy, Claude   Stet !"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Claude', 'Roy'])
  end

  it "should remove (MT) from a name" do
    input = "A.E. Porsild; stet! Luc Brouillet (MT) 2003"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['A.E.', 'Porsild'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Luc', 'Brouillet'])
  end

  it "should remove '(See Note Inside)'" do
    input = "Roy, Claude (See Note Inside)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Claude', 'Roy'])
  end

  it "should remove '(see note)'" do
    input = "Roy, Claude (see note)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Claude', 'Roy'])
  end

  it "should remove Bro." do
    input = "Brouard, Gustav G. Arsène, Bro."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Gustav G. Arsène", "Brouard"])
  end

  it "should not remove stet from the end of a name" do
    input = "Christian Kronenstet !"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Christian", "Kronenstet"])
  end

  it "should explode a complicated example" do
    input = "Vernon C. Brink; Thomas C. Brayshaw stet! 1979"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Vernon C.', 'Brink'])
    expect(parsed[1].values_at(:given, :family)).to eq(['Thomas C.', 'Brayshaw'])
  end

  it "should explode names with extraneous commas" do
    input = "4073 A.A. Beetle, with D.E. Beetle and Alva Hansen"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['A.A.', 'Beetle'])
    expect(parsed[1].values_at(:given, :family)).to eq(['D.E.', 'Beetle'])
    expect(parsed[2].values_at(:given, :family)).to eq(['Alva', 'Hansen'])
  end

  it "should explode names with extraneous period" do
    input = "C. Tanner.; M.W. Hawkes"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.', 'Tanner.'])
    expect(parsed[1].values_at(:given, :family)).to eq(['M.W.', 'Hawkes'])
  end

  it "should strip out dates like 21-12-1999 in the string" do
    input = "CJ Bird,21-12-1971"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['CJ', 'Bird'])
  end

  it "should strip out dates like 21 Dec. 1999 in the string" do
    input = "CJ Bird,21 Dec. 1999"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['CJ', 'Bird'])
  end

  it "should strip out year in string" do
    input = "Mortensen,Agnes Mols,2010"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['Agnes Mols', 'Mortensen'])
  end

  it "should strip out '(Photograph)" do
    input = "Robert J. Bandoni (Photograph)"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['Robert J.', 'Bandoni'])
  end

  it "should strip out 'Sight Identification" do
    input = "S.A. Redhead- Sight Identification"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['S.A.', 'Redhead'])
  end

  it "should strip out '(to subsp.)" do
    input = "Jeffery M. Saarela 2005 (to subsp.) "
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jeffery M.', 'Saarela'])
  end

  it "should strip out 'Fide:'" do
    input = "Bird, Carolyn J.; Fide: Lindsay, J.G."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Carolyn J.', 'Bird'])
    expect(parsed[1].values_at(:given, :family)).to eq(['J.G.', 'Lindsay'])
  end

  it "should strip out 'synonymie'" do
    input = "Université Laval - synonymie"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: nil, given: nil})
  end

  it "should explode names with Jan. 14, 2013 included in string" do
    input = "Jan Jones Jan. 14, 2013"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jan', 'Jones'])
  end

  it "should explode names with 'per'" do
    input = "G.J. Spencer per Sheila Lyons"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
  end

  it "should explode names with freeform dates in the string" do
    input = "Richard Robohm on 15 January 2013"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Richard', 'Robohm'])
  end

  it "should explode names with structured dates in the string" do
    input = "C.J. Bird 20/Aug./1980"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.J.', 'Bird'])
  end

  it "should explode names with dates separated by commas in the string" do
    input = "K. January; January, 1979"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['K.', 'January'])
  end
  
  it "should explode names with possibly conflicting months in the string" do
    input = "Michael May May 2013"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Michael', 'May'])
  end

  it "should explode names with months (in French) in the string" do
    input = "Jacques, Avril décembre 2013"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Avril', 'Jacques'])
  end

  it "should explode names with possibly conflicting months (in French) in the string" do
    input = "Jacques, Avril avril 2013"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Avril', 'Jacques'])
  end

  it "should explode names with a year and month (normal case) at the end of a string" do
    input = "Paul Kroeger 2006 May"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Paul', 'Kroeger'])
  end

  it "should explode names with a year and month (lower case) at the end of a string" do
    input = "Paul Kroeger 2006 may"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Paul', 'Kroeger'])
  end

  it "should explode names with spaces missing surrounding ampersand" do
    input = "Henrik Andersen&jon Feilberg"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Henrik', 'Andersen'])
    expect(parsed[1].values_at(:given, :family)).to eq([nil, 'Feilberg'])
    expect(@utility.clean(parsed[1]).to_h).to eq({ family: "Feilberg", given: "Jon"})
  end

  it "should explode a messy list" do
    input = "Winterbottom, R.;Katz, L.;& CI team"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['R.', 'Winterbottom'])
    expect(parsed[1].values_at(:given, :family)).to eq(['L.', 'Katz'])
    expect(parsed[2].values_at(:given, :family)).to eq(['CI', 'team'])
    expect(@utility.clean(parsed[2]).to_h).to eq({ family: nil, given: nil})
  end

  it "should reject an empty name" do
    input = "Norman Johnson and P"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(['Norman', 'Johnson'])
    expect(parsed[1].values_at(:given, :family)).to eq(["P", nil])
  end

  it "should ignore 'non précisé'" do
    input = "non précisé"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: nil, given: nil})
  end
  
  it "should parse name with given initials without period(s)" do
    input = "JH Picard"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['JH', 'Picard'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Picard", given: "J.H."})
  end

  it "should parse name when given is initalized and order is reversed without separator" do
    input = "Picard J.H."
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Picard', 'J.H.'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Picard", given: "J.H."})
  end

  it "should parse a name with a small family name" do
    input = "J.Z. Cao"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['J.Z.', 'Cao'])
  end

  it "should capitalize surnames like 'Jack smith'" do
    input = "Jack smith"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Jack', 'smith'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Smith", given: "Jack"})
  end

  it "should capitalize names like 'C. YOUNG'" do
    input = "C. YOUNG"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['C.', 'YOUNG'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Young", given: "C."})
  end

  it "should capitalize names like 'Chris R.T. YOUNG'" do
    input = "Chris R.T. YOUNG"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Chris R.T.', 'YOUNG'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Young", given: "Chris R.T."})
  end

  it "should capitalize names like 'CHRIS R.T. YOUNG'" do
    input = "CHRIS R.T. YOUNG"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['CHRIS R.T.', 'YOUNG'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Young", given: "Chris R.T."})
  end

  it "should properly handle and capitalize utf-8 characters" do
    input = "Sicard, Léas"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(['Léas', 'Sicard'])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "Sicard", given: "Léas"})
  end

  it "should ignore poorly parsed names with long given names and many periods" do
    input = "J. Green; R. Driskill; J. W. Markham L. D. Druehl"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(3)
    expect(parsed[0].values_at(:given, :family)).to eq(['J.', 'Green'])
    expect(@utility.clean(parsed[2]).to_h).to eq({ family: nil, given: nil })
  end

  it "should parse a whole bunch of names" do
    input = "Smith, William Leo; Bentley, Andrew C; Girard, Matthew G; Davis, Matthew P; Ho, Hsuan-Ching"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(5)
    expect(parsed[4].values_at(:given, :family)).to eq(['Hsuan-Ching', 'Ho'])
  end

  it "should ignore names with 'the'" do
    input = "The old bird was dead"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["The", "dead"])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: nil, given: nil })
  end

  it "should ignore names with 'unidentified'" do
    input = "Unidentified Beetle"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["Unidentified", "Beetle"])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: nil, given: nil })
  end

  it "should remove '(source)'" do
    input = "Tuck, Leslie M.; Vladykov, Vadim D. (source)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(["Leslie M.", "Tuck"])
    expect(parsed[1].values_at(:given, :family)).to eq(["Vadim D.", "Vladykov"])
  end

  it "should remove asterisks from a name" do
    input = "White*"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["White", nil])
    expect(@utility.clean(parsed[0]).to_h).to eq({ family: "White", given: nil })
  end

  it "should split with 'communicated to' in text" do
    input = "Huber Moore; communicatd to Terry M. Taylor"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(["Huber", "Moore"])
    expect(@utility.clean(parsed[1]).to_h).to eq({given: "Terry M.", family: "Taylor"})
  end

  it "should ignore a three letter family name without vowels" do
    input = "Jack Wft"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["Jack", "Wft"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: nil, family: nil})
  end

  it "should accept a three letter family name with a vowel" do
    input = "Jack Wit"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["Jack", "Wit"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: "Jack", family: "Wit"})
  end

  it "should ignore a family name with CAPs at end" do
    input = "Jack SmitH"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["Jack", "SmitH"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: nil, family: nil})
  end

  it "should ignore ignore a family name with two CAPs at the beginning" do
    input = "RGBennett"
    parsed = @utility.parse(input)
    expect(parsed[0].values_at(:given, :family)).to eq(["RGBennett", nil])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: nil, family: nil})
  end

  it "should split a string of names with a." do
    input = "R.K. Godfrey a. R.D. Houk"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(2)
    expect(parsed[0].values_at(:given, :family)).to eq(["R.K.", "Godfrey"])
    expect(parsed[1].values_at(:given, :family)).to eq(["R.D.", "Houk"])
  end

  it "should not split a string of names with A." do
    input = "R.K. A. Godfrey"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["R.K. A.", "Godfrey"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: "R.K.A.", family: "Godfrey"})
  end

  it "should not ignore the name Paula Maybee" do
    input = "Paula Maybee"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Paula", "Maybee"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: "Paula", family: "Maybee"})
  end

  it "it should not ignore the word maybe" do
    input = "Paula Maybee maybe"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Paula", "Maybee"])
    expect(@utility.clean(parsed[0]).to_h).to eq({given: "Paula", family: "Maybee"})
  end

  it "should strip out 'by correspondance" do
    input = "Stephen Darbyshire 2005 (by correspondance)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(1)
    expect(parsed[0].values_at(:given, :family)).to eq(["Stephen", "Darbyshire"])
  end

  it "should strip out 'operator', 'netter, and 'data recorder'" do
    input = "Holm, E (operator).; Ng, J.(netter); Litwiller, S. (netter); Lee, C. (data recorder)"
    parsed = @utility.parse(input)
    expect(parsed.size).to eq(4)
    expect(parsed[0].values_at(:given, :family)).to eq(["E", "Holm"])
    expect(parsed[1].values_at(:given, :family)).to eq(["J.", "Ng"])
    expect(parsed[2].values_at(:given, :family)).to eq(["S.", "Litwiller"])
    expect(parsed[3].values_at(:given, :family)).to eq(["C.", "Lee"])
  end
end
