#!/usr/bin/env ruby

require "json"
require "fileutils"
require "open3"
require "optparse"

ROOT = File.expand_path("..", __dir__)
DEFAULT_SOURCE_GLOBS = [
  "app/services/**/*.rb",
  "app/controllers/**/*.rb",
  "app/models/**/*.rb"
].freeze

MethodMetric = Struct.new(
  :file,
  :name,
  :start_line,
  :end_line,
  :complexity,
  :covered_lines,
  :relevant_lines,
  :coverage_percent,
  :crap_score,
  keyword_init: true
)

options = {
  coverage_path: File.join(ROOT, "tmp/crap_coverage.json"),
  markdown_path: nil,
  json_path: nil,
  run_tests: true,
  limit: 25
}

OptionParser.new do |parser|
  parser.banner = "Usage: tools/crap_score.rb [options]"
  parser.on("--coverage PATH", "Coverage JSON path") { |value| options[:coverage_path] = File.expand_path(value, ROOT) }
  parser.on("--markdown PATH", "Write markdown report") { |value| options[:markdown_path] = File.expand_path(value, ROOT) }
  parser.on("--json PATH", "Write JSON report") { |value| options[:json_path] = File.expand_path(value, ROOT) }
  parser.on("--skip-tests", "Use an existing coverage file") { options[:run_tests] = false }
  parser.on("--limit N", Integer, "Rows to print") { |value| options[:limit] = value }
end.parse!

def run_tests!(coverage_path)
  FileUtils.mkdir_p(File.dirname(coverage_path))
  env = {
    "PARALLEL_WORKERS" => "1",
    "CRAP_COVERAGE_OUTPUT" => coverage_path
  }
  stdout, stderr, status = Open3.capture3(env, "bin/rails", "test", chdir: ROOT)
  puts stdout
  warn stderr unless stderr.empty?
  abort "Test suite failed; CRAP report not trusted." unless status.success?
end

def source_files
  DEFAULT_SOURCE_GLOBS.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.sort
end

def strip_comments(line)
  line.sub(/#.*/, "")
end

def method_name(line)
  line[/^\s*def\s+(?:self\.)?([a-zA-Z_][a-zA-Z0-9_?!]*)/, 1]
end

def starts_block?(line)
  clean = strip_comments(line)
  return true if clean.match?(/^\s*(class|module|def|if|unless|case|while|until|for|begin)\b/)
  return true if clean.match?(/\b(do)\s*(\|[^|]*\|)?\s*$/)

  false
end

def ends_block?(line)
  strip_comments(line).match?(/^\s*end\b/)
end

def decision_count(line)
  clean = strip_comments(line)
  clean.scan(/\b(if|unless|elsif|when|while|until|rescue)\b|&&|\|\|/).size
end

def methods_in(file)
  methods = []
  stack = []

  File.readlines(file).each_with_index do |line, index|
    line_number = index + 1

    if (name = method_name(line))
      stack << { type: :method, name: name, start_line: line_number, complexity: 1 + decision_count(line) }
      next
    end

    stack.last[:complexity] += decision_count(line) if stack.last&.fetch(:type) == :method

    stack << { type: :block } if starts_block?(line)

    next unless ends_block?(line)

    closed = stack.pop
    next unless closed&.fetch(:type) == :method

    methods << {
      name: closed.fetch(:name),
      start_line: closed.fetch(:start_line),
      end_line: line_number,
      complexity: closed.fetch(:complexity)
    }
  end

  methods
end

def coverage_for(coverage_data, file, start_line, end_line)
  relative_path = file.delete_prefix("#{ROOT}/")
  lines = coverage_data.dig(relative_path, "lines") || []
  relevant = lines[(start_line - 1)..(end_line - 1)].to_a.compact
  covered = relevant.count(&:positive?)
  percent = relevant.empty? ? 0.0 : (covered.to_f / relevant.size * 100.0)
  [ covered, relevant.size, percent ]
end

def crap_score(complexity, coverage_percent)
  coverage = coverage_percent / 100.0
  (complexity**2 * (1.0 - coverage)**3 + complexity).round(2)
end

run_tests!(options.fetch(:coverage_path)) if options.fetch(:run_tests)

coverage_data = File.exist?(options.fetch(:coverage_path)) ? JSON.parse(File.read(options.fetch(:coverage_path))) : {}
metrics = source_files.flat_map do |file|
  methods_in(file).map do |method|
    covered, relevant, coverage_percent = coverage_for(coverage_data, file, method.fetch(:start_line), method.fetch(:end_line))

    MethodMetric.new(
      file: file.delete_prefix("#{ROOT}/"),
      name: method.fetch(:name),
      start_line: method.fetch(:start_line),
      end_line: method.fetch(:end_line),
      complexity: method.fetch(:complexity),
      covered_lines: covered,
      relevant_lines: relevant,
      coverage_percent: coverage_percent.round(1),
      crap_score: crap_score(method.fetch(:complexity), coverage_percent)
    )
  end
end

worst = metrics.sort_by { |metric| [ -metric.crap_score, -metric.complexity, metric.file, metric.start_line ] }

file_summaries = metrics.group_by(&:file).map do |file, file_metrics|
  {
    file: file,
    methods: file_metrics.size,
    max_crap: file_metrics.map(&:crap_score).max || 0,
    average_crap: (file_metrics.sum(&:crap_score) / file_metrics.size.to_f).round(2),
    uncovered_methods: file_metrics.count { |metric| metric.coverage_percent.zero? }
  }
end.sort_by { |summary| [ -summary.fetch(:max_crap), -summary.fetch(:average_crap), summary.fetch(:file) ] }

markdown = +"# CRAP Score Report\n\n"
markdown << "Generated with `tools/crap_score.rb` using Ruby Coverage line data and a conservative local cyclomatic-complexity estimate.\n\n"
markdown << "## Worst Methods\n\n"
markdown << "| CRAP | Complexity | Coverage | Method | File |\n"
markdown << "| ---: | ---: | ---: | --- | --- |\n"
worst.first(options.fetch(:limit)).each do |metric|
  markdown << "| #{metric.crap_score} | #{metric.complexity} | #{metric.coverage_percent}% | `#{metric.name}` | `#{metric.file}:#{metric.start_line}` |\n"
end
markdown << "\n## Worst Files\n\n"
markdown << "| Max CRAP | Avg CRAP | Methods | Uncovered methods | File |\n"
markdown << "| ---: | ---: | ---: | ---: | --- |\n"
file_summaries.first(options.fetch(:limit)).each do |summary|
  markdown << "| #{summary.fetch(:max_crap)} | #{summary.fetch(:average_crap)} | #{summary.fetch(:methods)} | #{summary.fetch(:uncovered_methods)} | `#{summary.fetch(:file)}` |\n"
end

json = {
  worst_methods: worst.map(&:to_h),
  worst_files: file_summaries
}

File.write(options.fetch(:markdown_path), markdown) if options[:markdown_path]
File.write(options.fetch(:json_path), JSON.pretty_generate(json)) if options[:json_path]

puts markdown
