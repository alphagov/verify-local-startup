#!/usr/bin/env ruby

require 'thread'
require 'os'
require 'tty-spinner'
require 'yaml'
require 'json'
require 'colorize'
require 'pry'

require_relative 'image_builder'
require_relative 'repository'

USAGE = <<ENDUSAGE
Usage:
    components -l
    components -s component
    components -r component
    components -c component
    components -S component
ENDUSAGE

HELP = <<ENDHELP
  Build Managment:
    -y, --yaml-file         Yaml file with a List of repos available to build

  Component Managment:
    -l, --list              List components by name
    -r, --restart           Specify a component to rebuild and restart
    -S, --stop              Specify a component to stop

  Help:
    -h, --help              Show's this help message

ENDHELP

THREAD_SUCCESS_MARKS = ["✅","🎉","🎆"]
SUCCESS_MARK = "🎆 🎉 ✅ 🎉 🎆"
ERROR_MARK = "❌ 😡 ❌ 😡 ❌"

def docker_ps
  output = `docker ps --format '"{{$v1 := split .Image ":"}}{{$shortName := index $v1 0}}{{$shortName}}": { "name": "{{.Names}}", "image": "{{.Image}}", "container": "{{.ID}}" },'`
  JSON.parse("{ #{output[0..-3]} }")
end

def list_components(repos)
  puts "Listing components:"
  repos.each do |repo_name, config|
    if docker_ps[repo_name].nil?
      running = " Stopped ".red
    else
      running = " Running ".green
    end
    puts "#{repo_name.ljust(20)} [#{running}]"
  end
end

def stop_component_wrapper(component_name)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Stopping component #{component_name.red}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Stopping...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  stop_spinner.auto_spin
  stop_component(component_name, stop_spinner)
end

def stop_component(component_name, spinner)
  component = docker_ps[component_name]
  if component.nil?
    spinner.success("Component not running.")
  else
    output = `docker stop #{component["name"]} 2>&1`
    if $?.success?
      spinner.success("Service #{component_name} has been stopped.")
    else
      spinner.error("Could not stop service #{component_name}")
      puts "Debug information:\n\tComponent_name = #{component_name}\n\tComponent = #{component}"
    end
  end
end

def build_component(component_name, repos, spinner)
  images = ""
  build_image = ImageBuilder.new(
      repo_name: component_name,
      config: repos[component_name],
      spinner: spinner,
      images: images,
      script_dir: File.expand_path(File.dirname(__FILE__)),
      retries: 2,
      write_success_log: false)
  build_image.run
end

def start_component_wrapper(component_name)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Starting component #{component_name.green}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Starting...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  stop_spinner.auto_spin
  start_component(component_name, stop_spinner)
end

def start_component(component_name, spinner)
  output = `docker-compose --env-file .env up -d #{component_name} 2>&1`
  if $?.success?
    spinner.success(" - Service #{component_name} has been started.")
  else
    spinner.error(" - Could not start service #{component_name}")
    puts "Debug information:\n\tComponent_name = #{component_name}\n\tDocker Output = #{output}"
  end
end

def role_component(repos, component_name, skip_build = false)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Rolling component #{component_name}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Stopping Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  build_spinner = loading_spinners.register("[:spinner] Building Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  start_spinner = loading_spinners.register("[:spinner] Starting Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  stop_spinner.auto_spin
  build_spinner.auto_spin
  start_spinner.auto_spin
  stop_component(component_name, stop_spinner)
  build_component(component_name, repos, build_spinner) unless skip_build
  start_component(component_name, start_spinner)
end

def main()
  args = { 
    :yaml=>'repos.yml', 
    :thread_count=>0, 
    :retries=>1, 
    :write_success_log=>false,
    :action=>nil,
    :component=>nil
  }
  unflagged_args = []
  next_arg = unflagged_args.first

  ARGV.each do |arg|
    case arg
      when '-h', '--help'               then args[:help] = true
      when '-y', '--yaml-file'          then next_arg = :yaml
      when '-l', '--list'               then args[:action] = "list"
      when '-r', '--restart'            then 
                                          args[:action] = "restart"
                                          next_arg = :component
      when '-s', '--start'              then
                                          args[:action] = "start"
                                          next_arg = :component
      when '-S', '--stop'               then 
                                          args[:action] = "stop"
                                          next_arg = :component
      when '-R', '--retry-build'        then next_arg = :retries
      else
        if next_arg
          args[next_arg] = arg
          unflagged_args.delete( next_arg )
        end
        next_arg = unflagged_args.first
    end
  end
  if args[:help]
    puts USAGE
    puts HELP if args[:help]
    exit
  end
  unless File.file?(args[:yaml])
    puts "Yaml file does not exist.  Exiting..."
    puts USAGE
    exit 1
  end

  # Load repos yaml
  repos = YAML.load(File.read(args[:yaml]))
  
  case args[:action]
    when "list"     then list_components(repos)
    when "start"    then start_component_wrapper(args[:component])
    when "stop"     then stop_component_wrapper(args[:component])
    when "restart"  then role_component(repos, args[:component])
  else
    puts "You need to specify an action."
    puts USAGE
    exit 1
  end
end

main
