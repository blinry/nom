Gem::Specification.new do |s|
  s.name        = "nom"
  s.version     = "0.1.1"
  s.add_runtime_dependency "nokogiri", "~> 1.6"
  s.executables << "nom"
  s.date        = "2015-07-08"
  s.summary     = "Lose weight and hair through stress and poor nutrition"
  s.description = "nom is a command line tool that helps you lose weight by
                   tracking your energy intake and creating a negative feedback loop.
                   It's inspired by John Walker's \"The Hacker's Diet\" and tries to
                   automate things as much as possible."
  s.authors     = ["Sebastian Morr"]
  s.email       = "sebastian@morr.cc"
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(README.md)
  s.requirements << 'gnuplot'
  s.homepage    = "https://github.com/blinry/nom"
  s.license     = "GPL-2.0+"
end
