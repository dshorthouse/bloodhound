describe "Bloodhound Application Controller" do

  it "should allow accessing the home page" do
    get '/'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public roster" do
    get '/roster'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public list of organizations" do
    get '/organizations'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public list of organizations/search" do
    get '/organizations/search'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public list of agents" do
    get '/agents'
    expect(last_response).to be_ok
  end

  it "should allow accessing the integrations page" do
    get '/integrations'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers search page" do
    get '/developers'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers structured-data page" do
    get '/developers/structured-data'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers raw-data page" do
    get '/developers/raw-data'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers code page" do
    get '/developers/code'
    expect(last_response).to be_ok
  end

  it "should allow accessing the collection data managers page" do
    get '/collection-data-managers'
    expect(last_response).to be_ok
  end

  it "should allow accessing the donate page" do
    get '/donate'
    expect(last_response).to be_ok
  end

  it "should allow accessing the donor wall page" do
    get '/donate/wall'
    expect(last_response).to be_ok
  end

  it "should allow accessing the how it works page" do
    get '/how-it-works'
    expect(last_response).to be_ok
  end

  it "should allow accessing the countries page" do
    get '/countries'
    expect(last_response).to be_ok
  end

  it "should allow accessing the articles page" do
    get '/articles'
    expect(last_response).to be_ok
  end

  it "should allow accessing the datasets page" do
    get '/datasets'
    expect(last_response).to be_ok
  end

  it "should allow accessing the about page" do
    get '/about'
    expect(last_response).to be_ok
  end

  it "should allow accessing the get-started page" do
    get '/get-started'
    expect(last_response).to be_ok
  end

  it "should allow accessing the offline page" do
    get '/offline'
    expect(last_response).to be_ok
  end

  it "should allow accessing the trainers page" do
    get '/trainers'
    expect(last_response).to be_ok
  end

  it "should allow accessing the on-this-day page" do
    get '/on-this-day'
    expect(last_response).to be_ok
  end

  it "should allow accessing the on-this-day/collected page" do
    get '/on-this-day/collected'
    expect(last_response).to be_ok
  end

  it "should allow accessing the about user rss feed" do
    get '/user.rss'
    expect(last_response).to be_ok
  end

  it "should allow accessing the organization json search" do
    get '/organization.json'
    expect(last_response).to be_ok
  end

  it "should allow accessing the user json search" do
    get '/user.json'
    expect(last_response).to be_ok
  end

  it "should allow accessing the agent json search" do
    get '/agent.json'
    expect(last_response).to be_ok
  end
end
