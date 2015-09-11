node[:deploy].each do |application, deploy|

  if deploy[:sidekiq]
    sidekiq_config = deploy[:sidekiq]
    release_path = ::File.join(deploy[:deploy_to], 'current')

    start_command = sidekiq_config[:start_command] ||
      "bundle exec sidekiq -e production -C config/sidekiq.yml"\
      "-r ./config/boot.rb 2>&1 >> log/sidekiq.log"

    number_of_workers = sidekiq_config[:number_of_workers] || 1

    env = deploy[:environment_variables] || {}

    template 'setup sidekiq-workers.conf' do
      path   "/etc/init/sidekiq-workers.conf"
      source 'sidekiq-workers.conf.erb'
      owner  'root'
      group  'root'
      mode   '0644'
      variables({
        number_of_workers: number_of_workers
      })
    end

    template 'setup sidekiq.conf' do
      path   "/etc/init/sidekiq.conf"
      source 'sidekiq.conf.erb'
      owner  'root'
      group  'root'
      mode   '0644'
      variables({
        user: deploy[:user],
        group: deploy[:group],
        release_path: release_path,
        start_command: start_command,
        env: env,
      })
    end

    service "sidekiq-workers" do
      provider Chef::Provider::Service::Upstart
      supports stop: true, start: true, restart: true, status: true
    end

    # Always restart sidekiq on deploy since we assume the code must
    # need to be reloaded.
    bash 'restart_sidekiq' do
      code "echo noop"
      notifies :restart, "service[sidekiq-workers]"
    end
  end
end
