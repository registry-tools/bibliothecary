require 'spec_helper'

describe Bibliothecary::Parsers::GitlabCi do
  it 'has a platform name' do
    expect(described_class.platform_name).to eq('gitlabci')
  end

  it 'parses dependencies from Gitlab CI file' do
    expect(described_class.analyse_contents('gitlab-ci.yml', load_fixture('gitlab-ci.yml'))).to eq({
      platform: "gitlabci",
      path: "gitlab-ci.yml",
      dependencies: [],
      kind: 'manifest',
      project_name: nil,
      success: true,
      git_info: nil,
    })
  end

  it "matches valid manifest filepaths" do
    expect(described_class.match?("gitlab-ci.yml")).to be_truthy
    expect(described_class.match?("Jenkinsfile")).to be_falsey
  end
end