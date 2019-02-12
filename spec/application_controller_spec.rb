

describe "Bloodhound Application" do

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

  it "should allow accessing the public list of agents" do
    get '/agents'
    expect(last_response).to be_ok
  end

  it "should allow accessing the integrations page" do
    get '/integrations'
    expect(last_response).to be_ok
  end

  it "should allow accessing the about page" do
    get '/about'
    expect(last_response).to be_ok
  end

end