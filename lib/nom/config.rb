require "nom/helpers"

module Nom
    class Config
        def initialize file
            @file = file

            @config = {}
            if File.exists? file
                @config = YAML.load_file(file)
            end

            @defaults = {
                # format: [ key, description, default_value, type ]
                "rate" => [ "how much weight you want to lose per week", 0.5, Float ],
                "goal" => [ "your target weight", nil, Float],
                "image_viewer" => [ "your preferred SVG viewer, for example 'eog -f', 'firefox', 'chromium'", Helpers::default_program, String ],
                "unit" => [ "your desired base unit in kcal", 1, Float ],
                "start_date" => [ "the first day that should be considered by nom [yyyy-mm-dd]", nil, Date ],
                "balance_start" => [ "the day from which on nom should keep track of a energy balance [yyyy-mm-dd]", nil, Date ],
                "balance_factor" => [ "how many money units you'll have to pay per energy unit", 0.01, Float ],
            }
        end

        def has key
            @config.has_key?(key) or (@defaults.has_key?(key) and not @defaults[key][1].nil?)
        end

        def get key
            v = nil
            if @config.has_key?(key)
                v = @config[key]
            elsif @defaults.has_key?(key)
                if @defaults[key][1].nil?
                    print "Please enter #{@defaults[key][0]}: "
                    @config[key] = STDIN.gets.chomp
                    open(@file, "w") do |f|
                        f << @config.to_yaml
                    end
                    v = @config[key]
                else
                    v = @defaults[key][1]
                end
            else
                raise "Unknown configuration option '#{key}'"
            end

            if key == "rate" and @config["rate"] < 0.1
               puts "Warning: rates smaller than 0.1 are not supported, capping to 0.1"
               0.1
            end

            if @defaults[key][2] == Float
                v.to_f
            elsif @defaults[key][2] == Date
                if v.class == Date
                    v
                else
                    Date.parse(v)
                end
            else
                v
            end
        end

        def print_usage
            puts "Configuration options (put these in #{@file}):"
            @defaults.each do |key, value|
                puts "      #{key}".ljust(34)+value[0].capitalize+(value[1].nil? ? "" : " (default: '#{value[1]}')")
            end
        end
    end
end
