#!/usr/bin/env ruby

require 'thread'
require 'os'
require 'tty-spinner'
require 'yaml'
require 'json'
require 'colorize'

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
  output = `docker ps -a --format '"{{$v1 := split .Image ":"}}{{$shortName := index $v1 0}}{{$shortName}}": { "name": "{{.Names}}", "image": "{{.Image}}", "container": "{{.ID}}", "state": "{{.State}}", "status": "{{.Status}}" },'`
  JSON.parse("{ #{output[0..-3]} }")
end

def docker_ls
  output = `docker image ls --format '"{{.Repository}}": { "tag": "{{.Tag}}", "image_id": "{{.ID}}", "created": "{{.CreatedAt}}", "created_since": "{{.CreatedSince}}"},'`
  JSON.parse("{ #{output[0..-3]} }")
end

def list_components(repos)
  container_info = docker_ls
  running_info = docker_ps
  name_heading = "Component Name".ljust(20)
  status_heading = "Status" + "".ljust(15)
  out = "#{name_heading} #{status_heading} Created\n".bold
  repos.each do |repo_name, config|
    process = running_info[repo_name] 
    process = container_info[repo_name] || {"state" => "missing"} if process.nil?
    running = case process["state"]
    when "running"  then "[ " + " Running ".green + " ]".ljust(10)
    when "missing"  then "[ " + "Not Built".red + " ]".ljust(10)
    else
      "[ " + " Stopped ".red + " ]".ljust(10)
    end
    container = container_info[repo_name] || {"created_since" => "Not Created Yet"}
    out = out + "#{repo_name.ljust(20)} #{running} #{container['created_since']}\n"
  end
  puts out
end

def stop_component_wrapper(component_name)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Stopping component #{component_name.bold}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
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
      spinner.success
    else
      spinner.error("Could not stop service #{component_name.bold}")
      puts "Debug information:\n\tComponent_name = #{component_name}\n\tComponent = #{component}"
    end
  end
end

def rebuild_component(repos, component_name)
  component = docker_ps[component_name]
  not_running = true
  not_running = component.state != running unless component.nil?
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Rebuild component #{component_name.bold}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Stopping Component...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡") unless not_running
  rm_spinner = loading_spinners.register("[:spinner] Removing old container...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  build_spinner = loading_spinners.register("[:spinner] Building new container...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  start_spinner = loading_spinners.register("[:spinner] Starting Component...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡") unless not_running
  stop_spinner.auto_spin unless not_running
  rm_spinner.auto_spin
  build_spinner.auto_spin
  start_spinner.auto_spin unless not_running
  stop_component(component_name, stop_spinner) unless not_running
  remove_component(component_name, rm_spinner)
  build_component(component_name, repos, build_spinner)

  if not_running
    puts "\nYou need to start the component as it wasn't running when rebuild was triggered.".red
    puts "\nTo start the component run:\n\t./component.sh -s #{component_name}"
  else
    start_component(component_name, start_spinner)
  end
end

def remove_component_wrapper(component_name)
  not_running = docker_ps[component_name].nil? 
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Removing component #{component_name.bold}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Stopping Component...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡") unless not_running
  rm_spinner = loading_spinners.register("[:spinner] Removing...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  stop_spinner.auto_spin unless not_running
  rm_spinner.auto_spin
  stop_component(component_name, stop_spinner) unless not_running
  remove_component(component_name, rm_spinner)
end

def remove_component(component_name, spinner)
  component = docker_ps[component_name]
  if component.nil?
    spinner.success("Container for component not found.")
  else
    output = `docker rm #{component["container"]}`
    output = output + `docker image rm #{component["image"]}`
    if $?.success?
      spinner.success
    else
      spinner.error("Unable to remove container for component #{component_name}")
      puts "Debug information:\n\tOutput = #{output}\n\tComponent_name = #{component_name}\n\tComponent = #{component}"
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

def start_component_wrapper(repos, component_name)
  build_image = docker_ls[component_name].nil?
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Starting component #{component_name.green}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  start_spinner = loading_spinners.register("[:spinner] Starting...", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  build_spinner = loading_spinners.register("[:spinner] Building Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡") if build_image
  build_spinner.auto_spin if build_image
  start_spinner.auto_spin
  build_component(component_name, repos, build_spinner) if build_image
  start_component(component_name, start_spinner)
end

def start_component(component_name, spinner)
  output = `docker-compose --env-file .env up -d #{component_name} 2>&1`
  if $?.success?
    spinner.success
  else
    spinner.error(" Could not start service #{component_name.bold}")
    puts "Debug information:\n\tComponent_name = #{component_name}\n\tDocker Output = #{output}"
  end
end

def roll_component(repos, component_name, skip_build = false)
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
      when '-rm', '--remove'            then
                                          args[:action] = "remove"
                                          next_arg = :component
      when '-rb', '--rebuild'           then
                                          args[:action] = "rebuild"
                                          next_arg = :component
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

  # Validate component name
  unless args[:action] == "list"
    if repos[args[:component]].nil?
      puts "Unknown component #{args[:component]}.  Availalbe components:"
      list_components(repos)
      exit 1
    end
  end
  
  case args[:action]
    when "list"     then list_components(repos)
    when "start"    then start_component_wrapper(repos, args[:component])
    when "stop"     then stop_component_wrapper(args[:component])
    when "restart"  then roll_component(repos, args[:component])
    when "remove"   then remove_component_wrapper(args[:component])
    when "rebuild"  then rebuild_component(repos, args[:component])
  else
    puts "You need to specify an action."
    puts USAGE
    exit 1
  end
end

main
