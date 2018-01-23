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

def build_thread(app, cmd, spinners, images)
  success_marks = ["✊","🙌","💪","👌","👍","👏"]
  spinner = spinners.register("[:spinner] #{app}", format: :dots, success_mark: "#{success_marks.sample} ", error_mark: "😡 ")
  spinner.auto_spin

  thread = Thread.new{
    output = `#{cmd} 2>&1`
    if $?.success?
      spinner.success
      images << "#{app.gsub('-', '_').upcase}_IMAGE=#{output.split("\n")[-1]}\n"
    else
      File.write("#{script_dir}/logs/#{app}_build.log", output, mode: "w")
      spinner.error(" - see logs/#{app}_build.log")
    end
  }
end

apps = YAML.load(File.read(ARGV[0]))
threads = []
apps.each do |app, cmd|
  thread = build_thread(app, cmd, loading_spinners, images)
  threads.push thread
end

threads.each do |thread| thread.join end
urls = File.read('urls.env')
File.write(".env", "#{urls}\n#{images}", mode: 'w')
