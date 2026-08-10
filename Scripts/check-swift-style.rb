#!/usr/bin/env ruby
# frozen_string_literal: true

MAX_FILE_LINES = 250
MAX_METHOD_LINES = 50
MIN_IDENTIFIER_LENGTH = 3
MAX_IDENTIFIER_LENGTH = 35
SWIFT_ROOTS = %w[App AppTests AppUITests Packages].freeze
IGNORED_SEGMENTS = %w[.build .derived .swiftpm].freeze

METHOD_PATTERN = /^\s*(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*
  (?:(?:public|private|internal|fileprivate|open|static|class|final|override|required|
  convenience|mutating|nonmutating|isolated|nonisolated)\s+)*(func|init|deinit)\b/x

# Mengambil seluruh Swift file yang menjadi bagian dari source dan test repository.
def swift_files
  SWIFT_ROOTS.flat_map { |root| Dir.glob("#{root}/**/*.swift") }
    .reject { |path| path.split("/").any? { |part| IGNORED_SEGMENTS.include?(part) } }
    .sort
end

# Menghapus comment dan string literal agar perhitungan brace tidak mudah tertipu.
def structural_line(line)
  without_comment = line.sub(%r{//.*$}, "")
  without_comment.gsub(/"(?:\\.|[^"\\])*"/, '""')
end

# Menemukan akhir body method menggunakan keseimbangan curly brace.
def method_end(lines, start_index)
  depth = 0
  isBodyStarted = false
  lines.each_index.drop(start_index).each do |index|
    structural = structural_line(lines[index])
    break if !isBodyStarted && index > start_index && structural.match?(METHOD_PATTERN)
    break if !isBodyStarted && structural.strip == "}"

    openingCount = structural.count("{")
    closingCount = structural.count("}")
    isBodyStarted ||= openingCount.positive?
    next unless isBodyStarted

    depth += openingCount - closingCount
    return index if depth.zero?
  end
  nil
end

# Memastikan comment tujuan berada tepat di atas method atau attribute method.
def is_method_documented?(lines, method_index)
  comment_index = method_index - 1
  while comment_index >= 0 && lines[comment_index].strip.start_with?("@")
    comment_index -= 1
  end
  comment_index >= 0 && lines[comment_index].strip.start_with?("//")
end

# Memecah daftar parameter tanpa memisahkan comma di dalam generic atau closure type.
def split_parameters(content)
  parameters = []
  current = +""
  depth = 0
  content.each_char do |character|
    depth += 1 if "([<".include?(character)
    depth -= 1 if ")] >".delete(" ").include?(character)
    if character == "," && depth.zero?
      parameters << current
      current = +""
    else
      current << character
    end
  end
  parameters << current unless current.strip.empty?
  parameters
end

# Mengambil nama internal parameter dari signature func atau initializer.
def method_parameter_names(lines, start_index)
  signature = lines[start_index, 20].to_a.map { |line| structural_line(line) }.join(" ")
  declaration = signature.match(/\b(?:func\s+[A-Za-z_][A-Za-z0-9_]*|init)\b/)
  return [] unless declaration

  opening_index = signature.index("(", declaration.end(0))
  return [] unless opening_index

  depth = 0
  closing_index = nil
  signature.each_char.with_index.drop(opening_index).each do |character, index|
    depth += 1 if character == "("
    depth -= 1 if character == ")"
    if depth.zero?
      closing_index = index
      break
    end
  end
  return [] unless closing_index

  content = signature[(opening_index + 1)...closing_index]
  split_parameters(content).filter_map do |parameter|
    prefix = parameter.split(":", 2).first
    tokens = prefix.scan(/[A-Za-z_][A-Za-z0-9_]*/)
      .reject { |token| %w[inout borrowing consuming isolated sending].include?(token) }
    tokens.last
  end
end

# Mengambil nama parameter closure eksplisit, termasuk closure dengan capture list.
def closure_parameter_names(structural)
  match = structural.match(/\{\s*(?:\[[^\]]*\]\s*)?([^{}]*?)\s+in\b/)
  return [] unless match

  content = match[1].strip
  return [] if content.empty? || content.start_with?("@")

  split_parameters(content).filter_map do |parameter|
    prefix = parameter.delete_prefix("(").delete_suffix(")").split(":", 2).first
    prefix.scan(/[A-Za-z_][A-Za-z0-9_]*/).last
  end
end

# Menambahkan pelanggaran bila nama variable berada di luar rentang yang disepakati.
def validate_identifier(path, line_number, name, violations)
  return if name.nil? || name == "_"
  return if (MIN_IDENTIFIER_LENGTH..MAX_IDENTIFIER_LENGTH).cover?(name.length)

  violations << "#{path}:#{line_number} variable '#{name}' harus #{MIN_IDENTIFIER_LENGTH}-" \
                "#{MAX_IDENTIFIER_LENGTH} karakter"
end

# Mengumpulkan pelanggaran ukuran, dokumentasi method, dan penamaan boolean.
def violations_for(path)
  lines = File.readlines(path)
  violations = []
  if lines.length > MAX_FILE_LINES
    violations << "#{path}:1 file memiliki #{lines.length} baris; maksimum #{MAX_FILE_LINES}"
  end

  lines.each_with_index do |line, index|
    next unless line.match?(METHOD_PATTERN)

    unless is_method_documented?(lines, index)
      violations << "#{path}:#{index + 1} method harus memiliki comment tujuan //"
    end
    methodEnd = method_end(lines, index)
    next unless methodEnd

    methodLength = methodEnd - index + 1
    if methodLength > MAX_METHOD_LINES
      violations << "#{path}:#{index + 1} method memiliki #{methodLength} baris; maksimum #{MAX_METHOD_LINES}"
    end
    method_parameter_names(lines, index).each do |name|
      validate_identifier(path, index + 1, name, violations)
    end
  end

  lines.each_with_index do |line, index|
    structural = structural_line(line)
    structural.scan(/\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)/).flatten.each do |name|
      validate_identifier(path, index + 1, name, violations)
    end
    structural.scan(/\b(?:let|var)\s*\(([^)]*)\)/).flatten.each do |tupleContent|
      split_parameters(tupleContent).each do |binding|
        tupleName = binding.strip.scan(/[A-Za-z_][A-Za-z0-9_]*/).first
        validate_identifier(path, index + 1, tupleName, violations)
      end
    end
    structural.scan(/\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b/).flatten.each do |name|
      validate_identifier(path, index + 1, name, violations)
    end
    closure_parameter_names(structural).each do |name|
      validate_identifier(path, index + 1, name, violations)
    end
    if (multilineClosure = structural.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s+in\s*$/))
      validate_identifier(path, index + 1, multilineClosure[1], violations)
    end
    if structural.match?(/\$[0-9]+/)
      violations << "#{path}:#{index + 1} shorthand closure variable harus diberi nama 3-35 karakter"
    end
    if (associatedValues = structural.match(/\bcase\s+[A-Za-z_][A-Za-z0-9_]*\((.*)\)/))
      split_parameters(associatedValues[1]).each do |parameter|
        next unless parameter.include?(":")

        label = parameter.split(":", 2).first.strip
        validate_identifier(path, index + 1, label, violations)
      end
    end
    structural.scan(/\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*Bool\b/).flatten.each do |name|
      next if name.start_with?("is")

      violations << "#{path}:#{index + 1} boolean '#{name}' harus memakai prefix is"
    end
    if structural.match?(/\bcase\s+[A-Za-z_][A-Za-z0-9_]*\(\s*Bool\s*\)/)
      violations << "#{path}:#{index + 1} associated Bool harus memiliki label berprefix is"
    end
  end
  violations
end

violations = swift_files.flat_map { |path| violations_for(path) }
unless violations.empty?
  warn "SWIFT STYLE VIOLATIONS:"
  violations.each { |violation| warn "- #{violation}" }
  exit 1
end

puts "Swift style checks passed: files <= #{MAX_FILE_LINES} lines, methods <= #{MAX_METHOD_LINES} lines, " \
     "variables are #{MIN_IDENTIFIER_LENGTH}-#{MAX_IDENTIFIER_LENGTH} characters, methods are commented, " \
     "and boolean flags use the is prefix."
