#!/usr/bin/env ruby
require 'os'
require 'tty-spinner'
require 'colorize'

# This is our worker thread which builds our docker images
class ImageBuilder
    attr_accessor :image_var, :messages
  
    def initialize(repo_name:, config:, spinner:, images:, script_dir:, retries:, write_success_log: false)
      @repo_name = repo_name
      @config = config
      @spinner = spinner
      @image_var = ""
      @script_dir = script_dir
      @success = false
      @release = "verify-local-startup dev"
      @retries = retries
      @write_success_log = write_success_log
      @output = "Starting build of #{repo_name}...\n"
    end
  
    def build_image
      image_name = "#{@repo_name}:local"
      build_args = @config.fetch('build-args', []).map { |ba| "--build-arg #{ba.keys[0]}=#{ba.values[0]}" }.join " "
      cmd = "docker build #{build_args}\
          --build-arg release=#{@release}\
          ../#{@config['context']}\
          -f ../#{@config['context']}/#{@config.fetch('dockerfile', 'Dockerfile')}\
          -t #{image_name}\
          2>&1"
      output = `#{cmd}`
      if $?.success?
        if @write_success_log
          @spinner.success(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
          @output = @output + output + "\nBuild failed... Unable to retry.\n" 
          File.write("#{@script_dir}/../logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
        else
          @spinner.success
        end
        @image_var = "#{@config['image_env_var']}=#{image_name}\n"
        @success = true
      elsif @retries > 0
        @output = @output + output + "\nBuild failed... Retrying...\n"
        @retries = @retries - 1
        build_image
      else
        @output = @output + output + "\nBuild failed... Unable to retry.\n" 
        File.write("#{@script_dir}/logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
        @spinner.error(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
        @success = false
      end
    end
  
    def get_release
      cmd = "git -C ../#{@config['context']} rev-parse --short HEAD"
      output = `#{cmd}`
      @release = output.strip
    end
  
    def run
      get_release
      build_image
    end
  
    def success?
      return @success
    end
  end
  
