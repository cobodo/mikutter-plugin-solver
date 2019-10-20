#!/usr/bin/env ruby

require 'pathname'
require 'yaml'
require 'fileutils'

require 'git' # gem install git

Hash.class_eval do
  def symbolize_keys
    self.map do |key, val|
      [key.to_sym, val]
    end.to_h
  end

  def deep_symbolize_keys
    self.map do |key, val|
      [key.to_sym, val.then(&(val.is_a?(Hash) ? :deep_symbolize_keys : :itself))]
    end.to_h
  end
end

MIKUTTER_ROOT = ENV.fetch('MIKUTTER_ROOT', '/usr/share/mikutter')
MIKUTTER_CONFROOT = ENV.fetch('MIKUTTER_CONFROOT', (Pathname(Dir.home) / '.mikutter').to_s)
MIKUTTER_PLUGIN_ROOT = (Pathname(MIKUTTER_CONFROOT) / 'plugin').to_s

def plugin_dirs
  [
    Pathname(MIKUTTER_ROOT) / 'core' / 'plugin',
    Pathname(MIKUTTER_PLUGIN_ROOT),
  ]
end

def dependencies(path)
  File.open(path, 'r') do |yml|
    informations = YAML.load(yml).deep_symbolize_keys
    names = informations.dig(:depends, :plugin).map(&:to_sym)
    urls = informations.dig(:plugin_urls) || {}
    names.map do |name|
      [name.to_sym, urls[name]]
    end.to_h
  end
end

def plugin_dir(name)
  (Pathname(MIKUTTER_PLUGIN_ROOT) / name.to_s).to_s
end

def plugin_entry(name, path: nil)
  path ||= Pathname(plugin_dir(name))
  depends =
    if path.directory? && (path / '.mikutter.yml').file?
      dependencies(path / '.mikutter.yml')
    end

  [
    name.to_s.to_sym,
    {
      solved: false,
      path: path,
      depends: depends,
    }
  ]
end

def plugin_entries
  plugin_dirs.inject([]) do |entries, target|
    entries
      .concat(target.glob('*/'))    # dir
      .concat(target.glob('*.rb'))  #file
  end.map do |entry|
    name = entry.file? ? entry.basename('.rb').to_s : entry.basename.to_s
    plugin_entry(name, path: entry)
  end.to_h
end

def mark_as_solved(info)
  info[:solved] = true
  info
end

def update_entries(entries)
  queue = []
  updated = entries.map do |name, info|
    next [name, info] if info[:solved]
    next [name, mark_as_solved(info)] if info[:depends].nil? || info[:depends].empty?

    not_exists = info[:depends].to_a.select {|name, _| !entries[name] }
    if not_exists.empty?
      info[:solved] = true
    else
      queue |= not_exists
    end

    [name, info]
  end

  [queue, updated].map(&:to_h)
end

def unsolved_entries(entries)
  entries
    .select {|name, info| !info[:solved] }
    .map(&:first)
    .sort
end

class PluginNotFoundError < StandardError; end

def url_type(url_info)
  url_info[:type]&.to_sym || :github
end

def actual_url(type, url)
  case type
  when :github
    "https://github.com/#{url}"
  when :gist
    "https://gist.github.com/#{url}"
  when :git, :local_copy, :local_symlink
    url
  else
    # unknown
    url
  end
end

def get_by_git(name, url, branch: nil)
  g = Git.clone(url, name.to_s, path: MIKUTTER_PLUGIN_ROOT)
  g.checkout(branch) if branch
  g
end

def get_by_symlink(name, path)
  File.symlink path, plugin_dir(name)
end

def get_by_local_copy(name, path)
  FileUtils.cp_r path, plugin_dir(name)
end

def get_plugins(queue)
  count = queue.size
  index = 0
  queue.map do |name, url_info|
    next unless url_info
    type = url_type(url_info)
    url = actual_url(type, url_info[:url])

    index += 1
    puts "install(#{index}/#{count}): #{name} ..."
    begin
      case type
      when :github, :gist, :git
        get_by_git(name, url, branch: url_info[:branch])
      when :local_symlink
        get_by_symlink(name, url)
      when :local_copy
        get_by_local_copy(name, url)
      else
        # unknown
      end
    rescue => e
      puts e.message
      puts e.backtrace
    end

    plugin_entry(name)
  end.compact.to_h
end

puts "MIKUTTER_ROOT = #{MIKUTTER_ROOT}"
puts "MIKUTTER_CONFROOT = #{MIKUTTER_CONFROOT}"

entries = plugin_entries
previous = nil
while true
  queue, entries = update_entries(entries)
  break if queue.empty?
  current = unsolved_entries(entries)
  if previous == current
    # TODO: test
    pp [queue, entries]
    raise PluginNotFoundError.new("取得元が見つからないプラグインがあります： #{current.join(", ")}")
  end
  previous = current
  entries.merge! get_plugins(queue)
end

exit(true)

