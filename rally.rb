#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'yaml'
require 'rally_rest_api'
require 'launchy'
require 'html2md'
require 'term/ansicolor'

@@message_file = "RALLY_MSG"

action = :display
text = nil
story = nil
c = Term::ANSIColor
config = YAML.load_file(ENV['HOME']+'/.rallyconf.yml')['rally']

parser = OptionParser.new do |o|
    o.banner = "Usage: rally -[options] [rally id]"
    o.on('-b', '--block', '(un)block the story/defect') do
        action = :block
    end
    o.on('-n', '--notes', 'append text to notes') do
        action = :notes
    end
    o.on('-l', '--launch', 'open user story/defect in web browser') do
        action = :launch
    end
    o.on('-s s', '--story s', 'specify the user story number') do |s|
        story = s.upcase
    end
    o.on('-h', '--help', 'Print this help message') do
        puts o
        exit
    end
end
parser.parse!


text = ARGV[0]

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

def printable_state(rally_story)
    c = Term::ANSIColor
    states = {"D" => "Defined", "P" => "In-Progress", "C" => "Completed", "A" => "Accepted"}
    bg = c.on_green
    state_string = ""
    ["D", "P", "C", "A"].each do |s|
        bg = c.on_red if (rally_story.blocked == "true" && (states[s] == rally_story.schedule_state))
        state_string += bg + s
        bg = c.reset if (states[s] == rally_story.schedule_state)
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
    r = connect_to_rally(config['url'], config['username'], config['password'])
    workspace = r.find_all(:workspace).first
    type = (story.start_with?("US") && :userstory) || :defect
    rally_story = r.find(:artifact, :workspace => workspace) {equal :formatted_i_d, story }.find { |s| s.formatted_i_d == story}
    if action == :display
        # id_color = type == :defect && c.red || c.blue
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
        puts c.bold('State: ') + printable_state(rally_story)
    elsif action == :block
        blocked = rally_story.blocked == "true"
        # text = prompt_for_text
        text = "TODO: implement external text editing"
        block_state = blocked && c.cyan("unblocked") || c.red("blocked")
        if text
            r.update(rally_story, :blocked => !blocked)
            puts "#{block_state} #{type.to_s} #{rally_story.formatted_i_d}"
        else
            puts "Aborting block change due to empty message"
            # notes = HTMLPage.new :contents => rally_story.notes
            # puts notes.markdown
            # TODO: add/replace message and convert back to html
        end
    elsif action == :notes
        text ||= prompt_for_text
        if text
            r.update(rally_story, action => rally_story.send(action.to_s) + "<br>" + text)
            puts "added #{action.to_s}"
        else
            puts "Aborting block change due to empty message"
        end
    else
        url = "#{config['url']}/#/detail/#{type.to_s}/#{rally_story.object_i_d}"
        puts "launching #{url}"
        Launchy.open(url)
    end
end
