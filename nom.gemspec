# nom – helps you lose weight by tracking your energy intake
# Copyright (C) 2014-2023  blinry <mail@blinry.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

Gem::Specification.new do |s|
  s.name        = "nom"
  s.version     = "0.1.5"
  s.add_runtime_dependency "nokogiri", "~> 1.6"
  s.executables << "nom"
  s.summary     = "Lose weight and hair through stress and poor nutrition"
  s.description = "nom is a command line tool that helps you lose weight by
                   tracking your energy intake and creating a negative feedback loop.
                   It's inspired by John Walker's \"The Hacker's Diet\" and tries to
                   automate things as much as possible."
  s.authors     = ["blinry"]
  s.email       = "mail@blinry.org"
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(README.md)
  s.requirements << 'gnuplot'
  s.homepage    = "https://github.com/blinry/nom"
  s.license     = "GPL-2.0+"
end
