#!/usr/bin/env ruby
# frozen_string_literal: true

MAX_FILE_LINES = 250
MAX_METHOD_LINES = 50
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
  end

  lines.each_with_index do |line, index|
    structural = structural_line(line)
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
     "methods are commented, and boolean flags use the is prefix."
