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

module Nom
    class Helpers
        def Helpers::open_file filename
            program = if filename =~ /\.svg$/
                default_program
            else
                # let's assume it's a text file
                default_editor
            end

            if program.nil?
                raise "Couldn't find a program to open '#{filename}'. Please file a bug."
            end
            system("#{program} #{filename}")
        end

        def Helpers::default_program
            if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
                "start"
            elsif RbConfig::CONFIG['host_os'] =~ /darwin/
                "open"
            elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
                "xdg-open"
            else
                nil
            end
        end

        def Helpers::default_editor
            ENV["EDITOR"] ||
                if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
                    "notepad"
                elsif RbConfig::CONFIG['host_os'] =~ /darwin/
                    "open -a TextEdit"
                elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
                    "vi"
                else
                    nil
                end
        end
    end
end
