#!/usr/bin/env ruby

require 'fileutils'

EDITOR="#{ENV['HOME']}/bin/subl"
FILENAME=File.expand_path('~/.todo.xit')

##
## data model
##
Todo = Struct.new(:state, :priority, :title, :date, :tags, :text) do
  def add_text(_text)
    @text ||= ""
    @text += _text
  end

  def to_swiftbar
    prefix = []
    suffix = []
    sfs = 1

    suffix << "sfsize=18"

    if state == 'x'
      prefix << ":checkmark.square:"
      suffix << "sfcolor=#555555"
      suffix << "color=#555555"
    elsif state == '@'
      prefix << ":minus.square:"
      suffix << "sfcolor=#00FF00"
    else
      prefix << ":square:"
      suffix << "sfcolor=#000000"
    end

    if priority > 0
      sfs += 1
      suffix << "sfcolor#{sfs}=#FF0000"

      if priority >= 3
        prefix << ":exclamationmark.3:"
      elsif priority >= 2
        prefix << ":exclamationmark.2:"
      else
        prefix << ":exclamationmark:"
      end
    end

    display_title = title.to_s.gsub("|", ":")
    display_title = display_title[0...80] + "..." if display_title.size > 80
    prefix << display_title

    suffix << "terminal=False bash=#{$0} param1=toggle param2='#{title}' refresh=True"

    "#{prefix.join(' ')} | #{suffix.join(' ')}"
  end
end

Group = Struct.new(:title, :todos) do
  def todos
    @todos || []
  end

  def add(todo)
    @todos ||= []
    @todos << todo
  end

  def active?
    todos.detect { |t| t.state == '@' }
  end

  def todo_count
    todos.reduce(0) { |c,t| c + (t.state == 'x' ? 0 : 1) }
  end

  def to_swiftbar
    lines = []
    lines << "**#{title}** | md=true refresh=True" if "#{title}" != ""
    lines += todos.collect(&:to_swiftbar)
    lines.join("\n")
  end
end

class Parser
  def initialize
    @groups = []
  end

  def to_swiftbar
    @groups.collect(&:to_swiftbar).join("\n---\n")
  end

  def todos_count
    [@groups.reduce(0) { |c,g| c + g.todo_count }, 50].min
  end

  def active?
    @groups.detect { |g| g.active? }
  end

  def parse_lines(lines)
    group = Group.new
    @groups << group
    todo = nil

    lines.each do |line|
      if line =~ /^\[([ x@~?])\] (!+ )?(.*)$/
        # todo line, set values
        todo = Todo.new
        todo.state = $1
        todo.priority = $2.to_s.count('!')
        todo.title = $3.to_s.strip
        group.add(todo)
        next

      elsif "#{line}" == ""
        # empty line, start new group
        group = Group.new
        @groups << group
        next

      elsif todo && line =~ /^    /
        # line starts with 4 spaces, extra text on todo
        todo.add_text(line)
        next

      else
        # for anything else on the line, set group title
        group.title = line.strip
        next
      end
    end
  end

  def to_swiftbar
    lines = []

    prefix = []
    suffix = []
    suffix << "sfsize=19"

    if active?
      prefix << ":#{todos_count}.square.fill:"
      suffix << "sfcolor=#00FF00"
    else
      prefix << ":#{todos_count}.square:"
    end



    lines << "#{prefix.join(' ')} | #{suffix.join(' ')}"
    lines << ":arrow.clockwise: Refresh | refresh=True"
    lines += @groups.collect(&:to_swiftbar)
    lines << "Open #{FILENAME} in editor | terminal=False bash=#{EDITOR} param0=#{FILENAME}"

    lines.join("\n---\n")
  end
end

def toggle_todo!(filename, title)
  updated_lines = []
  updated = false

  File.open(filename, "r").each_line do |line|
    if line =~ /^\[(.)\] / && line.include?(title)
      old_state = $1.to_s
      new_state = case $1.to_s
                  when 'x'
                    ' '
                  when '@'
                    'x'
                  when ' '
                    '@'
                  end
      updated_lines << line.gsub(/^\[#{old_state}\]/, "[#{new_state}]")
      updated = true
    else
      updated_lines << line
    end
  end

  if updated
    File.write(filename, updated_lines.join)
  end
  updated
end

##
## actions
##
case ARGV[0]
when 'toggle'
  title = ARGV[1..].join(' ')
  toggle_todo!(FILENAME, title)
  exit
end

##
## parse
##
FileUtils.touch(FILENAME) unless File.exist?(FILENAME)
lines = File.read(FILENAME).split("\n")

parser = Parser.new
parser.parse_lines(lines)

##
## output
##
puts parser.to_swiftbar
