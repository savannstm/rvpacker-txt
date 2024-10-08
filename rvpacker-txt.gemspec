# frozen_string_literal: true

Gem::Specification.new do |spec|
    spec.name = 'rvpacker-txt'
    spec.version = '1.13.0'
    spec.authors = ['Howard Jeng', 'Andrew Kesterson', 'Solistra', 'Darkness9724', 'savannstm']
    spec.email = ['savannstm@gmail.com']
    spec.summary = 'Reads RPG Maker XP/VX/VXAce game text to .txt files and writes them to their initial form.'
    spec.homepage = 'https://github.com/savannstm/rvpacker-txt'
    spec.license = 'MIT'
    spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

    spec.metadata = { 'homepage_uri' => 'https://github.com/savannstm/rvpacker-txt' }

    spec.files = %w[
        bin/rvpacker-txt
        lib/classes.rb
        lib/read.rb
        lib/write.rb
        lib/extensions.rb
        Gemfile
        LICENSE.md
        README.md
        rvpacker-txt.gemspec
    ]
    spec.executables = ['rvpacker-txt']
    spec.require_paths = ['lib']
end
