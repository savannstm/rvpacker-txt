Gem::Specification.new do |spec|
    spec.name = 'rvpacker-txt'
    spec.version = '1.3.1'
    spec.authors = ['Howard Jeng', 'Andrew Kesterson', 'Solistra', 'Darkness9724', 'savannstm']
    spec.email = ['savannstm@gmail.com']
    spec.summary = 'Reads or writes RPG Maker XP/VX/VXAce game text to .txt files'
    spec.homepage = 'https://github.com/savannstm/rvpacker-txt'
    spec.license = 'MIT'
    spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

    spec.metadata = { 'homepage_uri' => 'https://github.com/savannstm/rvpacker-txt' }

    spec.files = `git ls-files -z`.split("\x0")
    spec.executables = ['rvpacker-txt']
    spec.require_paths = ['lib']

    spec.add_development_dependency 'bundler', '~> 2.5'
    spec.add_development_dependency 'rake', '~> 13.0'
end
