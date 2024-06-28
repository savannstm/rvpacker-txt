# frozen_string_literal: true

require_relative 'lib/rvpacker/version'

Gem::Specification.new do |spec|
    spec.name = 'rvpacker-ng'
    spec.version = RVPACKER::VERSION
    spec.authors = ['Howard Jeng', 'Andrew Kesterson', 'Solistra', 'Darkness9724']
    spec.email = ['darkness9724@gmail.com']
    spec.summary = 'Pack and unpack any RPG Maker VX Ace data files'
    spec.homepage = 'https://gitlab.com/Darkness9724/rvpacker-ng'
    spec.license = 'MIT'
    spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

    spec.files = `git ls-files -z`.split("\x0")
    spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ['lib']

    spec.add_development_dependency 'bundler', '2.5.14'
    spec.add_development_dependency 'rake', '13.0.6'
    spec.add_dependency 'formatador', '0.3.0'
    spec.add_dependency 'optimist', '3.0.1'
    spec.add_dependency 'psych', '3.3.2'
    spec.add_dependency 'scanf', '1.0.0'
end
