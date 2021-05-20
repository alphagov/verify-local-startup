#!/usr/bin/env ruby
require 'os'
require 'tty-spinner'
require 'colorize'
require 'fileutils'
require 'tempfile'
require 'securerandom'

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
      random_namespace = SecureRandom.hex # To prevent race conditions with separate threads
      temp_m2_dirname = "m2_#{random_namespace}"
      temp_dockerfile = "Dockerfile_#{random_namespace}"
      dockerfile_content = insert_maven_local_copy_in_dockerfile(
        "../#{@config['context']}/#{@config.fetch('dockerfile', 'Dockerfile')}",
        temp_m2_dirname
      )
      File.open("../#{@config['context']}/#{temp_dockerfile}", 'w') { |f| f.write dockerfile_content }
      FileUtils.cp_r "#{`realpath ~`.strip}/.m2/repository/uk/gov/ida/.", "../#{@config['context']}/#{temp_m2_dirname}"
      cmd = "docker build #{build_args}\
          --build-arg release=#{@release}\
          ../#{@config['context']}\
          -f ../#{@config['context']}/#{temp_dockerfile}\
          -t #{image_name}\
          2>&1"
      output = `#{cmd}`
      FileUtils.rm_rf("../#{@config['context']}/#{temp_m2_dirname}")
      FileUtils.rm_rf("../#{@config['context']}/#{temp_dockerfile}")
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
        File.write("#{@script_dir}/../logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
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

    def insert_maven_local_copy_in_dockerfile(dockerfile_path, m2_dir)
      output = ""
      dockerfile = File.new(dockerfile_path)
      dockerfile.each do |line|
        if line.start_with? 'WORKDIR' # We need the maven local repo available in each stage of the build
          output << line
          output << "COPY #{m2_dir}/ /root/.m2/repository/uk/gov/ida/\n"
        else
          output << line
        end
      end
      output
    end
  end
  