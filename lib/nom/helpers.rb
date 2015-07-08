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
