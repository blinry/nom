require "open-uri"
require "fileutils"
require "nokogiri"
require "uri"
require "tempfile"
require "erb"

require "nom/food_entry"
require "nom/config"
require "nom/weight_database"
require "nom/helpers"

module Nom
    class Nom
        def initialize
            @nom_dir = File.join(Dir.home,".nom")
            if not Dir.exists? @nom_dir
                puts "Creating #{@nom_dir}"
                Dir.mkdir(@nom_dir)
            end

            @config = Config.new(File.join(@nom_dir, "config"))

            @weights = WeightDatabase.new(File.join(@nom_dir, "weight"))
            @inputs = read_file("input", FoodEntry)

            date = truncate_date
            @inputs.delete_if{|i| i.date < date}
            @weights.truncate(date)

            if @weights.empty?
                print "Welcome to nom! Please enter your current weight: "
                weight [STDIN.gets.chomp]
            end

            @weights.interpolate_gaps!
            @weights.precompute_moving_average!(0.1, 0.1, goal, rate)
            @weights.predict_weights!(rate, goal, 30)
            @weights.precompute_moving_average!(0.1, 0.1, goal, rate)

            precompute_inputs_at
            precompute_base_rate_at
        end

        def status
            kg_lost = @weights.moving_average_at(@weights.first) - @weights.moving_average_at(@weights.last_real)
            print "#{kg_lost.round(1)} kg down"
            if kg_lost+kg_to_go > 0
                print " (#{(100*kg_lost/(kg_lost+kg_to_go)).round}%)"
            end
            print ", #{kg_to_go.round(1)} kg to go!"
            print " You'll reach your goal in approximately #{format_duration(days_to_go)}."
            puts

            log_since([@weights.first,Date.today-1].max)
        end

        def log
            log_since(@weights.first)
        end

        def grep args
            term = args.join(" ")

            inputs = @inputs.select{|i| i.description =~ Regexp.new(term, Regexp::IGNORECASE)}

            if inputs.empty?
                puts "(no matching entries found)"
            end

            inputs.each do |i|
                entry(quantize(i.kcal), i.date.to_s+" "+i.description)
            end

            separator
            entry(quantize(inputs.inject(0){|sum, i| sum+i.kcal}), "total")
        end

        def weight args
            if @weights.real?(Date.today)
                raise "You already entered a weight for today. Use `nom editw` to modify it."
            end

            date = Date.today
            weight = args.pop.to_f

            open(File.join(@nom_dir,"weight"), "a") do |f|
                f << "#{date} #{weight}\n"
            end

            initialize
            plot
        end

        def nom args
            nom_entry args, (Time.now-5*60*60).to_date
        end

        def yesterday args
            nom_entry args, Date.today-1
        end

        def search args
            puts "Previous log entries:"
            grep(args)
            term = args.join(" ")
            puts
            term = term.encode("ISO-8859-1")
            url = "http://fddb.info/db/de/suche/?udd=0&cat=site-de&search=#{URI.escape(term)}"

            page = Nokogiri::HTML(open(url))
            results = page.css(".standardcontent a").map{|a| a["href"]}.select{|href| href.include? "lebensmittel"}

            results[0..4].each do |result|
                page = Nokogiri::HTML(open(result))
                title = page.css(".breadcrumb a").last.text
                brand = page.css(".standardcontent p a").select{|a| a["href"].include? "hersteller"}.first.text
                puts "#{title} (#{brand})"

                page.css(".serva").each do |serving|
                    size = serving.css("a.servb").text
                    kcal = serving.css("div")[5].css("div")[1].text.to_i
                    #kj = serving.css("div")[2].css("div")[1].text.to_i
                    puts "    (#{quantize(kcal)}) #{size}"
                end
            end
        end

        def plot
            raise "To use this subcommand, please install 'gnuplot'." unless which("gnuplot")

            weight_dat = Tempfile.new("weight")
            (@weights.first).upto(plot_end) do |date|
                weight_dat << "#{date}\t"
                if @weights.real?(date)
                    weight_dat << "#{@weights.at(date)}"
                else
                    weight_dat << "-"
                end
                if date <= @weights.last_real
                    weight_dat << "\t#{@weights.moving_average_at(date)}\t"
                else
                    weight_dat << "\t-"
                end
                if date >= @weights.last_real
                    weight_dat << "\t#{@weights.moving_average_at(date)}\n"
                else
                    weight_dat << "\t-\n"
                end
            end
            weight_dat.close

            input_dat = Tempfile.new("input")
            input_dat << "#{@weights.first-1}\t0\t0\n"
            (@weights.first).upto(Date.today) do |date|
                input_dat << "#{date}\t"
                if consumed_at(date) == 0
                    input_dat << "-"
                else
                    input_dat << quantize(consumed_at(date))
                end
                input_dat << "\t#{quantize(allowed_kcal(date, 0))}"
                input_dat << "\t#{quantize(allowed_kcal(date))}"
                input_dat << "\n"
            end
            input_dat.close

            svg = Tempfile.new(["plot", ".svg"])
            svg.close
            ObjectSpace.undefine_finalizer(svg) # prevent the svg file from being deleted

            plt_erb = IO.read(File.join(File.dirname(File.expand_path(__FILE__)), "nom.plt.erb"))

            plt = Tempfile.new("plt")
            plt << ERB.new(plt_erb).result(binding)
            plt.close

            system("gnuplot "+plt.path)

            image_viewer = @config.get("image_viewer")
            system(image_viewer+" "+svg.path)
        end

        def edit
            Helpers::open_file File.join(@nom_dir, "input")
        end

        def editw
            Helpers::open_file File.join(@nom_dir, "weight")
        end

        def config
            Helpers::open_file File.join(@nom_dir, "config")
        end

        def config_usage
            @config.print_usage
        end

        def stats
            statistics = [
                # [ description, streakable, lambda ]
                ["weight loss", false, lambda {|d| @weights.moving_average_at(d) - @weights.moving_average_at(d+1)}],
                ["days with input entries", true, lambda {|d| not inputs_at(d).empty?}],
                ["days with weight entry", true, lambda {|d| @weights.real?(d)}],
                ["days under goal", true, lambda {|d| inputs_at(d).inject(0){|sum, i| sum + i.kcal} <= allowed_kcal(d)}],
                ["energy consumed", false, lambda {|d| sum = inputs_at(d).inject(0){|sum, i| sum + i.kcal}; sum == 0 ? nil : sum }],
                ["energy under goal", false, lambda {|d| sum = inputs_at(d).inject(0){|sum, i| sum + i.kcal}; sum == 0 ? nil : allowed_kcal(d) - sum }],

            ]
            statistics.each do |description, streakable, lam|
                puts "#{description}"

                if streakable
                    streak = 0
                    streak_start = nil
                    longest_streak = 0
                    longest_streak_start = nil
                    @weights.first.upto(@weights.last_real-1) do |d|
                        if lam.call(d)
                            if streak == 0
                                streak_start = d
                            end
                            streak += 1
                        else
                            if streak > longest_streak
                                longest_streak = streak
                                longest_streak_start = streak_start
                            end
                            streak = 0
                        end
                    end

                    print "Longest streak: "
                    if longest_streak_start
                        print "#{longest_streak_start} - #{longest_streak_start+longest_streak-1} "
                    end
                    puts "(#{longest_streak} days)"

                    print "Current streak: "
                    if streak > 0
                        print "#{streak_start} - #{streak_start+streak-1} "
                    end
                    puts "(#{streak} days)"
                else
                    values = @weights.first.upto(@weights.last_real-1).map{|d| [d, lam.call(d)]}.select{|d,v| v != nil}
                    max = values.max_by{|d,v| v}
                    min = values.min_by{|d,v| v}
                    avg = values.inject(0){|sum, v| sum + v[1]}/values.size
                    puts "Max: #{max[1]} on #{max[0]}"
                    puts "Min: #{min[1]} on #{min[0]}"
                    puts "Avg: #{avg}/day, #{avg*7}/week"

                end
                puts
            end
=begin
            balances = []
            missing_inputs = 0
            streak = 0
            streak_start = nil
            longest_streak = 0
            longest_streak_start = nil
            @weights.first.upto(@weights.last_real) do |d|
                if consumed_at(d) == 0
                    missing_inputs += 1
                else
                    balances << consumed_at(d) - allowed_kcal(d)
                end

                if consumed_at(d) <= allowed_kcal(d)
                    if streak == 0
                        streak_start = d
                    end
                    streak += 1
                else
                    if streak > longest_streak
                        longest_streak = streak
                        longest_streak_start = streak_start
                    end
                    streak = 0
                end
            end
            avg = balances.inject(0){|sum, d| sum + d}/balances.size

            puts "Days without input: #{missing_inputs}"
            puts "Ate an average of (#{quantize(avg)}) too much per day. High: (#{quantize(balances.max)}) Low: (#{quantize(balances.min)})"
            rate = (@weights.at(@weights.first)-@weights.at(@weights.last_real))/(@weights.last_real-@weights.first)*7
            puts "Effective loss rate: #{rate.round(1)} kg/week"
            puts "Longest streak: #{longest_streak_start} - #{longest_streak_start+longest_streak-1} (#{longest_streak} days)"

            rate_dat = Tempfile.new("rate")
            @weights.first.upto(@weights.last_real-1) do |d|
                if consumed_at(d) != 0 and @weights.real?(d) and @weights.real?(d+1)
                    #rate_dat << "#{(weight_at(d+1)-weight_at(d))*7}\t#{consumed_at(d)}\n"
                    #rate_dat << "#{(moving_average_at(d+1)-moving_average_at(d))*7}\t#{allowed_kcal(d)}\n"
                    #rate_dat << "#{(moving_average_at(d+1)-moving_average_at(d))*7}\t#{consumed_at(d)-allowed_kcal(d)}\n"
                    rate_dat << "#{(@weights.at(d+1)-@weights.at(d))*7}\t#{consumed_at(d)-allowed_kcal(d)}\n"
                    #rate_dat << "#{consumed_at(d)}\t#{allowed_kcal(d)}\n"
                end
            end
            rate_dat.close

            svg = Tempfile.new(["plot", ".svg"])
            svg.close

            plt_erb = IO.read(File.join(File.dirname(__FILE__), "stats.plt.erb"))

            plt = Tempfile.new("plt")
            plt << ERB.new(plt_erb).result(binding)
            plt.close

            system("gnuplot "+plt.path)

            image_viewer = @config.get("image_viewer")
            system(image_viewer+" "+svg.path)
=end
        end

        private

        def nom_entry args, date
            summands = args.pop.split("+")
            number = summands.inject(0) do |sum, summand|
                factors = summand.split("x")
                sum + factors.map{ |f| f.to_f }.inject(1){ |p,f| p*f }
            end

            kcal = dequantize(number)

            if kcal == 0
                raise "energy term cannot be zero"
            end

            description = args.join(" ")
            entry = FoodEntry.new(date, kcal, description)

            open(File.join(@nom_dir,"input"), "a") do |f|
                if not @inputs.empty? and entry.date != @inputs.last.date
                    f << "\n"
                end
                f << entry.to_s
            end

            @inputs << entry
            if @inputs_at[date].nil?
                @inputs_at[date] = []
            end
            @inputs_at[date] << entry

            status
        end

        def allowed_kcal date, r=nil
            if r.nil?
                r = @weights.rate_at(date, goal, rate)
            end
            if date > @weights.last
                date = @weights.last
            end
            @base_rate_at[date] + r*1000
        end

        def consumed_at date
            inputs_at(date).inject(0){ |sum, i| sum+i.kcal }
        end

        def kg_to_go
            @weights.moving_average_at(Date.today) - goal
        end

        def kcal_to_burn
            kcal_per_kg_body_fat = 7000
            kg_to_go * kcal_per_kg_body_fat
        end

        def days_to_go
            kcal_to_burn.abs/(rate*1000)
        end

        def plot_end
            @weights.last
        end

        def balance_start
            if @config.has("balance_start")
                @config.get("balance_start")
            else
                @weights.first
            end
        end

        def balance_end
            Date.today-1
        end

        def kcal_balance
            sum = 0
            balance_start.upto(balance_end) do |d|
                if consumed_at(d) != 0
                    sum += consumed_at(d) - allowed_kcal(d)
                end
            end
            sum
        end

        def truncate_date
            if @weights.empty? or Date.today - @weights.last_real > 30
                return Date.today
            end

            first_start = @weights.first

            if @config.has("start_date")
                user_start = @config.get("start_date")
                [user_start, first_start].max
            else
                # find the last gap longer than 30 days
                gap = @weights.find_gap(30)

                if gap.nil?
                    first_start
                else
                    gap[1]
                end
            end
        end

        def quantize kcal
            (1.0*kcal/@config.get("unit")).round
        end

        def dequantize number
            (1.0*number*@config.get("unit")).round
        end

        def format_date date
            if date == Date.today
                return "Today"
            elsif date == Date.today-1
                return "Yesterday"
            else
                return date.to_s
            end
        end

        def format_duration days
            if days <= 7
                n = days.round(1)
                unit = "day"
            elsif days <= 7*4
                n = (days/7.0).round(1)
                unit = "week"
            else
                n = (days/7.0/4.0).round(1)
                unit = "month"
            end
            "#{n} #{unit}#{n == 1 ? "" : "s"}"
        end

        def entry value, text=""
            puts "#{" "*(6-value.to_s.length)}(#{value}) #{text}"
        end

        def separator
            puts "---------------------"
        end

        def log_since start
            remaining = 0
            start.upto(Date.today) do |date|
                remaining += allowed_kcal(date)
                puts
                puts "#{format_date(date)}: (#{quantize(allowed_kcal(date))})"
                puts
                remaining = allowed_kcal(date)
                inputs_at(date).each do |i|
                    entry(quantize(i.kcal), i.description)
                    remaining -= i.kcal
                end
                separator
                entry(quantize(remaining), "remaining (#{(100-100.0*quantize(remaining)/quantize(allowed_kcal(date))).round}% used)")
            end
            if kcal_balance > 0 and @config.has("balance_start")
                cost = if @config.has("balance_factor")
                           " (cost: %.2f)" % (@config.get("balance_factor")*quantize(kcal_balance)).round(2)
                       else
                           ""
                       end
                entry(quantize(kcal_balance), "too much since #{balance_start}#{cost}")
            end
        end

        def read_file name, klass
            result = []
            file = File.join(@nom_dir,name)
            FileUtils.touch(file)
            IO.readlines(file).each do |line|
                next if line == "\n"
                result << klass::from_line(line)
            end
            result
        end

        def goal
            @config.get("goal")
        end

        def rate
            @config.get("rate")
        end

        def inputs_at date
            @inputs_at[date] || []
        end

        def precompute_inputs_at
            @inputs_at = {}
            @inputs.each do |i|
                @inputs_at[i.date] = [] if @inputs_at[i.date].nil?
                @inputs_at[i.date] << i
            end
        end

        def precompute_base_rate_at
            alpha = 0.05
            @base_rate_at = {@weights.first => @weights.at(@weights.first)*25*1.2}

            (@weights.first+1).upto(@weights.last) do |d|
                intake = consumed_at(d-1)
                if intake == 0
                    @base_rate_at[d] = @base_rate_at[d-1]
                    next
                end
                loss = @weights.moving_average_at(d-1) - @weights.moving_average_at(d)
                kcal_per_kg_body_fat = 7000
                burned_kcal = loss*kcal_per_kg_body_fat
                new_base_rate_estimation = intake + burned_kcal
                @base_rate_at[d] = alpha*new_base_rate_estimation + (1-alpha)*@base_rate_at[d-1]
            end
            (@weights.last+1).upto(Date.today) do |d|
                @base_rate_at[d] = @base_rate_at[d-1]
            end
        end

        def which(cmd)
            exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
            ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
                exts.each { |ext|
                    exe = File.join(path, "#{cmd}#{ext}")
                    return exe if File.executable?(exe) && !File.directory?(exe)
                }
            end
            return nil
        end
    end
end
