#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'yaml'
require 'rally_rest_api'
require 'launchy'
require 'extensions/kernel'
require 'html2markdown'
require 'term/ansicolor'

action = :display
story = nil
c = Term::ANSIColor
config = YAML.load_file(ENV['HOME']+'/.rallyconf.yml')['rally']

parser = OptionParser.new do |o|
    o.banner = "Usage: rally -[options] [rally id]"
    o.on('-l', '--launch', 'Open user story or defect in web browser') do
        action = :launch
    end
    o.on('-h', '--help', 'Print this help message') do
        puts o
        exit
    end
end
parser.parse!

if ARGV[0]
    story = ARGV[0].upcase
else
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
    custom_headers.name = 'Rally CRY'
    custom_headers.version = '0.1'
    custom_headers.vendor = 'rallycry'
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

def print_state(rally_story)
	c = Term::ANSIColor
    states = {"D" => "Defined", "P" => "In Progress", "C" => "Completed", "A" => "Accepted"}
	bg = c.on_green
	state_string = ""
    ["D", "P", "C", "A"].each do |s|
		bg = c.on_red if (rally_story.blocked == "true" && (states[s] == rally_story.schedule_state))
    	state_string += bg + s
    	bg = c.reset if (states[s] == rally_story.schedule_state)
    end
    return state_string + c.reset
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
            desc = HTMLPage.new :contents => rally_story.description
            print_text(desc.markdown)
        end
        puts
        puts c.bold('Project: ') + rally_story.project.name
        puts c.bold('State: ') + print_state(rally_story)
    else
        url = "#{config['url']}/#/detail/#{type.to_s}/#{rally_story.object_i_d}"
        puts "launching #{url}"
        Launchy.open(url)
    end
end
