#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'trollop'
require 'rally_rest_api'
require 'launchy'
require 'html2md'
require 'term/ansicolor'

@@message_file = "RALLY_MSG"

story = nil
c = Term::ANSIColor
config = YAML.load_file(ENV['HOME']+'/.rallyconf.yml')['rally']

SUB_COMMANDS = %w(show block notes launch workon)
global_opts = Trollop::options do
    banner <<-EOS
Usage: rally [options] [command [command-options]]
Available commands: #{SUB_COMMANDS.join("\n" + (" " * 20))}
EOS
    opt :story, "user story number", :type => :string
    stop_on SUB_COMMANDS
end
cmd = ARGV.shift # get the subcommand
action = cmd && cmd.to_sym || :show
cmd_opts = case cmd
    when "show"
        Trollop::options do
            banner "Block a user story"
            opt :tasks, "display a list of the tasks for the story", :type => :bool
        end
    when "block"
        Trollop::options do
            banner "Block a user story"
        end
    when "notes"
        Trollop::options do
            banner "Append to the notes section of a story"
            opt :message, "message to add to notes section", :type => :string
        end
    when "launch"
        Trollop::options do
            banner "Launch in web browser"
        end
    when "launch"
        Trollop::options do
            banner "Creates a task and sets it to In-Progress"
        end
end

text = cmd_opts.message if cmd_opts
story = global_opts.story.upcase()
unless story
    # determine story id from the current git branch
    branch = IO.popen("git rev-parse --abbrev-ref HEAD") { |io|  io.first.strip }
    story = /\b(?:US|us|DE|de)\d+\b/.match(branch)[0].upcase
end

def connect_to_rally(rally_url, username, password)
    baseurl = rally_url + '/slm'
    if baseurl[baseurl.length-1, baseurl.length] == "/"
        baseurl = baseurl.slice(0, baseurl.length-1)
    end
    custom_headers = CustomHttpHeader.new
    custom_headers.name = 'Rally CRI'
    custom_headers.version = '0.1'
    custom_headers.vendor = 'rallycri'
    begin
        return  RallyRestAPI.new(:username => username, :password => password, :base_url => baseurl, :http_headers => custom_headers)
    rescue => ex
        raise("\nERROR: Could not connect to Rally! Error returned: #{ex.message}")
    end
end

def print_text(text)
    line_width = 79
    puts text.gsub(/\n/, "\n\n").gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n")
end

def printable_state(blocked, state)
    c = Term::ANSIColor
    states = {"D" => "Defined", "P" => "In-Progress", "C" => "Completed", "A" => "Accepted"}
    bg = c.on_green
    state_string = ""
    ["D", "P", "C", "A"].each do |s|
        bg = c.on_red if (blocked == "true" && (states[s] == state))
        state_string += bg + s
        bg = c.reset if (states[s] == state)
    end
    return state_string + c.reset
end    

def prompt_for_text
    editor = IO.popen("git config --get core.editor") { |io|  io.first.strip } || "vi"
    system(editor, @@message_file)
    if File.exists?(@@message_file)
        message = File.read(@@message_file)
        File.delete(@@message_file)
        return message
    end
    return nil
end

if story
    story = story.upcase()
    r = connect_to_rally(config['url'], config['username'], config['password'])
    workspace = r.find_all(:workspace).first
    rally_story = r.find(:artifact, :workspace => workspace) {equal :formatted_i_d, story }.find { |s| s.formatted_i_d == story}
    type = (story.start_with?("US") && :userstory) || :defect
    if action == :show
        id_color = c.blue
        title =  "#{rally_story.formatted_i_d}: #{rally_story.name}"
        puts id_color + c.bold(title)
        puts  id_color + '-' * (title.length) + c.reset
        if rally_story.description
            puts c.bold('Description:')
            desc = Html2Md.new(rally_story.description)
            print_text(desc.parse)
        end
        puts c.bold('Project: ') + rally_story.project.name
        puts c.bold('Iteration: ') + rally_story.iteration.name
        puts c.bold('State: ') + printable_state(rally_story.blocked, rally_story.schedule_state)
        if cmd_opts && cmd_opts.tasks
            puts c.bold('Tasks: ')
            rally_story.tasks.each {|task| puts "State: #{printable_state(task.blocked, task.state)} Name: #{task.name}"}
        end
    elsif action == :block
        blocked = rally_story.blocked == "true"
        block_state = blocked && c.cyan("unblocked") || c.red("blocked")
        r.update(rally_story, :blocked => !blocked)
        puts "#{block_state} #{type.to_s} #{rally_story.formatted_i_d}"
    elsif action == :notes
        text ||= prompt_for_text
        if text
            r.update(rally_story, action => rally_story.send(action.to_s) + "<br>" + text)
            puts "added #{action.to_s}"
        else
            puts "Aborting block change due to empty #{action.to_s}"
        end
    elsif action == :workon
        # r.create(:task, :name =>  ARGV.shift, :work_product => rally_story)
        task = RestObject.new
        task.type = :task
        task.rally_rest = r
        task.name = ARGV.shift
        task.estimate = ARGV.shift
        task.state = "In-Progress"
        task.work_product = rally_story
        task.save!
        puts "Working on: " + task.formatted_i_d
    else
        url = "#{config['url']}/#/detail/#{type.to_s}/#{rally_story.object_i_d}"
        puts "launching #{url}"
        Launchy.open(url)
    end
end
