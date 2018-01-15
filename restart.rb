#!/usr/bin/env ruby

require 'yaml'
require 'tty-spinner'

app = ARGV[0]
cmd = YAML.load(File.open('apps.yml'))[app]

spinner = TTY::Spinner::new("[:spinner] Building #{app}", format: :arrow_pulse, success_mark: "Done!", error_mark: "Failed")
spinner.auto_spin
output = `#{cmd} 2>&1`
if $?.success?
  spinner.success
  image = output.split("\n")[-1]
else
  File.write("#{script_dir}/logs/#{app}_build.log", output, mode: "w")
  spinner.error(" - see logs/#{app}_build.log")
end
image_env_var = "#{app.gsub('-', '_').upcase}_IMAGE=#{output.split("\n")[-1]}"
`#{image_env_var} docker-compose up -d #{app}`
