#!/usr/bin/env ruby
require 'os'
require 'tty-spinner'
require 'colorize'

class Repository
    def initialize(repo_name:, spinners:)
      @repo_name = repo_name
      @spinners = spinners
      @success = false
      @spinner = nil
    end
  
    def get_repo
      cmd = "git clone https://github.com/alphagov/#{@repo_name}.git ../#{@repo_name} 2>&1"
      output = `#{cmd}`
      unless $?.success?
        File.write("#{@script_dir}/logs/#{@repo_name}_fetch.log", output, mode: "w")
        @spinner.error(" failed to clone repository - see #{@script_dir}/logs/#{@repo_name}_fetch.log")
        @success = false
        false
      end
      @spinner.success
      true
    end
  
    def run
      have_repo = true
      unless File.exists?("../#{@repo_name}")
        @spinner = @spinners.register("[:spinner] Fetching #{@repo_name} from GitHub", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
        @spinner.auto_spin
        @success = get_repo
      else
        @success = true
      end
    end
  
    def success?
      return @success
    end
  end