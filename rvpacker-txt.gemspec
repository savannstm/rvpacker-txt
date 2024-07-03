Gem::Specification.new do |spec|
    spec.name = 'rvpacker-txt'
    spec.version = '1.2.0'
    spec.authors = ['Howard Jeng', 'Andrew Kesterson', 'Solistra', 'Darkness9724', 'savannstm']
    spec.email = ['savannstm@gmail.com']
    spec.summary = 'Reads or writes RPG Maker XP/VX/VXAce game text to .txt files'
    spec.homepage = 'https://github.com/savannstm/rvpacker-txt'
    spec.license = 'MIT'
    spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

    spec.files = `git ls-files -z`.split("\x0")
    spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ['lib']

    spec.add_development_dependency 'bundler', '>= 2.5.14'
    spec.add_development_dependency 'rake', '>= 13.0.6'
end
