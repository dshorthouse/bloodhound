# encoding: utf-8
require_relative "./spec_helper"

describe "Test the similarity of given names" do
  before(:all) do
    @w = Bloodhound::DisambiguateWorker.new
  end

  it "should give J. and John a score of 1" do
    given1 = "J."
    given2 = "John"
    expect(@w.weight(given1,given2)).to eq 1
  end

  it "should give John R. and John a score of 1.1" do
    given1 = "John R."
    given2 = "John"
    expect(@w.weight(given1,given2)).to eq 1.1
  end

  it "should give J.D. and J. a score of 1.1" do
    given1 = "J.D."
    given2 = "J."
    expect(@w.weight(given1,given2)).to eq 1.1
  end

  it "should give John R. and J.R. a score of 2" do
    given1 = "John R."
    given2 = "J.R."
    expect(@w.weight(given1,given2)).to eq 2
  end

  it "should give John Robert and John a score of 1.1" do
    given1 = "John Robert"
    given2 = "John"
    expect(@w.weight(given1,given2)).to eq 1.1
  end

  it "should give John Robert and John R. a score of 2" do
    given1 = "John Robert"
    given2 = "John R."
    expect(@w.weight(given1,given2)).to eq 2
  end
  
  it "should give John R. and J.R.W. a score of 2" do
    given1 = "John R."
    given2 = "J.R.W."
    expect(@w.weight(given1,given2)).to eq 2
  end

  it "should give Jim B. and Jay a score of 0" do
    given1 = "Jim B."
    given2 = "Jay"
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give John R. and John F. a score of 0" do
    given1 = "John R."
    given2 = "John F."
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give J.R. and J.F. a score of 0" do
    given1 = "J.R."
    given2 = "J.F."
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give J.F.W. and J.F.R. a score of 0" do
    given1 = "J.F.W."
    given2 = "J.F.R."
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give Jack and John a score of 0" do
    given1 = "Jack"
    given2 = "John"
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give Jack and Peter a score of 0" do
    given1 = "Jack"
    given2 = "Peter"
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give Jack P. and Jack Peter a score of 2" do
    given1 = "Jack P."
    given2 = "Jack Peter"
    expect(@w.weight(given1,given2)).to eq 2
  end

  it "should give Jack Robert and Jack Richard a score of 0" do
    given1 = "Jack Robert"
    given2 = "Jack Richard"
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give J. Robert and Jack Robert a score of 2" do
    given1 = "J. Robert"
    given2 = "Jack Robert"
    expect(@w.weight(given1,given2)).to eq 2
  end

  it "should give J. Richard and Jack Robert a score of 0" do
    given1 = "J. Richard"
    given2 = "Jack Robert"
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give J.Wagner J. and John J. a score of 0" do
    given1 = "J.Wagner J."
    given2 = "John J."
    expect(@w.weight(given1,given2)).to eq 0
  end

  it "should give J.BollinG and J.V. a score of 0" do
    given1 = "J.BollinG"
    given2 = "J.V."
    expect(@w.weight(given1,given2)).to eq 0
  end

end