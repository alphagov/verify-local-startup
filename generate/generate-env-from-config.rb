#!/usr/bin/env ruby
require 'yaml'
require 'base64'
require 'open-uri'
require_relative 'pki'
require_relative 'urls'

def get_env_vars(config_contents)
  env_var_pattern=/\$\{([a-z_A-Z]+):?-?\}/

  env_vars = config_contents.map { |line|
    matches = env_var_pattern.match(line.strip)
    matches&.captures&.fetch(0)
  }.compact.uniq

  env = PKI::env.merge(Urls::env)
  env.slice(*env_vars)
end

config_files = YAML.load_file("#{File.expand_path(File.dirname(__FILE__))}/config-files.yml")
config_files.each do |proj, config|
  env_hash = get_env_vars(open(config).read.lines)
  File.open("#{proj}.env", 'w') do |f|
    f.write(env_hash.map { |k,v| "#{k}=#{v}" }.join("\n"))
  end
end
