# Checks for everypolitician-data pull requests and creates deployment events
class HandleEverypoliticianDataPullRequestJob
  include Sidekiq::Worker

  attr_accessor :pull_request
  attr_reader :github

  def initialize(github = Everypoliticianbot.github)
    @github = github
  end

  def perform(pull_request)
    @pull_request = pull_request
    return unless valid?
    if opened_or_synchronized?
      pull_request_updated_countries_json? &&
        create_deployment_event(pull_request['pull_request']['head']['sha'])
      update_countries_json
    elsif merged?
      trigger_webhook
      master = github.branch(everypolitician_data_repo, 'master')
      create_deployment_event(master[:commit][:sha], merge: true)
    end
  end

  private

  def valid?
    pull_request['repository']['full_name'] == everypolitician_data_repo
  end

  def pull_request_updated_countries_json?
    files = github.pull_files(everypolitician_data_repo, pull_request['number'])
    files.map { |f| f[:filename] }.flatten.uniq.include?('countries.json')
  end

  def opened_or_synchronized?
    %w(opened synchronize).include?(pull_request['action'])
  end

  def create_deployment_event(sha, payload = {})
    github.create_deployment(
      everypolitician_data_repo,
      sha,
      auto_merge: false,
      environment: 'viewer-sinatra',
      payload: payload.merge(pull_request_number: pull_request['number'])
    )
  end

  def update_countries_json
    branch = pull_request['pull_request']['head']['ref']
    UpdateCountriesJsonJob.perform_async(branch)
  end

  def merged?
    pull_request['action'] == 'closed' && pull_request['pull_request']['merged']
  end

  def trigger_webhook
    applications = Application.exclude(webhook_url: '')
    applications.each do |application|
      SendWebhookJob.perform_async(application.webhook_url)
    end
  end

  def everypolitician_data_repo
    ENV['EVERYPOLITICIAN_DATA_REPO']
  end
end
