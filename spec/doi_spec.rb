# encoding: utf-8
require_relative "./spec_helper"

describe "Utility function for DOI" do
  before(:all) do
    @utility = Bloodhound::AgentUtility
  end

  it "should clean a doi with http://dx.doi.org" do
    input = "http://dx.doi.org/10.12345/12345"
    cleaned = @utility.doi_clean(input)
    expect(cleaned).to eq("10.12345/12345")
  end

  it "should clean a doi with http://doi.org" do
    input = "http://doi.org/10.12345/12345"
    cleaned = @utility.doi_clean(input)
    expect(cleaned).to eq("10.12345/12345")
  end

  it "should clean a doi with doi:" do
    input = "doi:10.12345/12345"
    cleaned = @utility.doi_clean(input)
    expect(cleaned).to eq("10.12345/12345")
  end

  it "should clean a doi with DOI:" do
    input = "DOI:10.12345/12345"
    cleaned = @utility.doi_clean(input)
    expect(cleaned).to eq("10.12345/12345")
  end

  it "should clean a doi with DOI= " do
    input = "DOI= 10.12345/12345"
    cleaned = @utility.doi_clean(input)
    expect(cleaned).to eq("10.12345/12345")
  end
end