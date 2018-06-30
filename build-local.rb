#!/usr/bin/env ruby

require 'tty-spinner'
require 'yaml'

puts <<-'BANNER'
    ____        _ __    ___                ___
   / __ )__  __(_) /___/ (_)___  ____ _   /   |  ____  ____  _____
  / __  / / / / / / __  / / __ \/ __ `/  / /| | / __ \/ __ \/ ___/
 / /_/ / /_/ / / / /_/ / / / / / /_/ /  / ___ |/ /_/ / /_/ (__  )
/_____/\__,_/_/_/\__,_/_/_/ /_/\__, /  /_/  |_/ .___/ .___/____/
                              /____/         /_/   /_/👉 😎 👉 Zoop!
BANNER

script_dir = File.expand_path(File.dirname(__FILE__))

success_marks = "✊ 🙌 💪 👌 👍 👏 "
error_mark = "❌ 😤 ❌ 😤 ❌ "
loading_spinners = TTY::Spinner::Multi.new("[:spinner] Building apps", format: :arrow_pulse, success_mark: "#{success_marks} ", error_mark: error_mark)
images = ""

def build_thread(repo_name, opts, spinners, images, script_dir)
  success_marks = ["✊","🙌","💪","👌","👍","👏"]
  spinner = spinners.register("[:spinner] #{repo_name}", format: :dots, success_mark: "#{success_marks.sample} ", error_mark: "😡 ")
  spinner.auto_spin

  thread = Thread.new{
    image_name = "#{repo_name}:local"
    output = `docker build #{opts['context']} -f #{opts['context']}/#{opts.fetch('dockerfile', 'Dockerfile')} -t #{image_name} 2>&1`
    if $?.success?
      spinner.success
      images << "#{opts['image_env_var']}=#{image_name}\n"
    else
      File.write("#{script_dir}/logs/#{repo_name}_build.log", output, mode: "w")
      spinner.error(" - see logs/#{repo_name}_build.log")
    end
  }
end

repos = YAML.load(File.read(ARGV[0]))
threads = []
repos.each do |repo_name, opts|
  thread = build_thread(repo_name, opts, loading_spinners, images, script_dir)
  threads.push thread
end

threads.each do |thread| thread.join end
File.write(".env", images, mode: 'a')
