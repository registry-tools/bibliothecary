require 'spec_helper'

describe Bibliothecary::Parsers::Jenkins do
  it 'has a platform name' do
    expect(described_class.platform_name).to eq('jenkins')
  end

  it 'parses dependencies from Jenkinsfile' do
    expect(described_class.analyse_contents('Jenkinsfile', load_fixture('Jenkinsfile'))).to eq({
      platform: "jenkins",
      path: "Jenkinsfile",
      dependencies: [],
      kind: 'manifest',
      project_name: nil,
      success: true,
      git_info: nil,
    })
  end

  it "matches valid manifest filepaths" do
    expect(described_class.match?("Jenkinsfile")).to be_truthy
    expect(described_class.match?("Gerkinsfile")).to be_falsey
  end
end