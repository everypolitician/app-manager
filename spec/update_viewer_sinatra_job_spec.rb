require 'spec_helper'

describe UpdateViewerSinatraJob do
  let(:github_updater) { Minitest::Mock.new }
  subject { UpdateViewerSinatraJob.new(github_updater) }

  describe 'perform' do
    it "doesn't run anything if push isn't valid" do
      subject.perform({})
      github_updater.verify
    end

    it 'updates DATASOURCE with countries_json_url if push is valid' do
      push = {
        'after' => 'f77e664',
        'ref' => 'refs/heads/master',
        'commits' => [
          { 'added' => ['countries.json'], 'modified' => [] }
        ]
      }
      countries_json_url = 'https://raw.githubusercontent.com/' \
        'everypolitician/everypolitician-data/' \
        "#{push['after']}/countries.json"
      updater = Minitest::Mock.new
      github_updater.expect(
        :new,
        updater,
        [ENV['VIEWER_SINATRA_REPO'], 'DATASOURCE']
      )
      updater.expect(:update, true, [countries_json_url])
      subject.perform(push)
      github_updater.verify
      updater.verify
    end
  end

  describe 'push_ref_is_master?' do
    it 'is true when ref is master' do
      subject.push = { 'ref' => 'refs/heads/master' }
      assert subject.push_ref_is_master?
    end

    it 'is false when ref is not master' do
      subject.push = { 'ref' => 'refs/heads/develop' }
      refute subject.push_ref_is_master?
    end
  end

  describe 'countries_json_pushed?' do
    it 'is true when countries.json is added or modified' do
      subject.push = {
        'commits' => [
          { 'added' => ['countries.json'], 'modified' => [] }
        ]
      }
      assert subject.countries_json_pushed?
    end

    it 'is false when countries.json is not changed or modified' do
      subject.push = {
        'commits' => [
          { 'added' => ['README'], 'modified' => [] }
        ]
      }
      refute subject.countries_json_pushed?
    end
  end

  describe 'push_valid?' do
    it 'is true for countries.json pushed to master' do
      subject.push = {
        'ref' => 'refs/heads/master',
        'commits' => [
          { 'added' => ['countries.json'], 'modified' => [] }
        ]
      }
      assert subject.push_valid?
    end
  end
end
