require "rubygems"
require "nokogiri"
require "uri"
require "open-uri"
require "date"
require "yaml"
require "fileutils"

class WeightEntry
    attr_reader :date, :weight

    def self.from_line line
        date, weight = line.split(" ", 2)
        date = Date.parse(date)
        weight = weight.to_f
        WeightEntry.new(date, weight)
    end

    def initialize date, weight
        @date = date
        @weight = weight
    end

    def to_s
        "#{@date} #{@weight}\n"
    end
end

class FoodEntry
    attr_reader :date, :kcal, :description

    def self.from_line line
        date, kcal, description = line.split(" ", 3)
        date = Date.parse(date)
        kcal = kcal.to_i
        description.chomp!
        FoodEntry.new(date, kcal, description)
    end

    def initialize date, kcal, description
        @date = date
        @kcal = kcal
        @description = description
    end

    def to_s
        "#{@date} #{@kcal} #{@description}\n"
    end
end

class Nom
    def initialize
        @weights = []
        @inputs = []

        @config_dir = Dir.home+"/.nom/"

        config = YAML.load_file(@config_dir+"config")
        @height = config["height"].to_f
        @goal = config["goal"].to_f
        @rate = config["rate"].to_f
        @unit = config["unit"].to_f
        @skip_first = 7

        @weights = read_file("weight", WeightEntry)
        @inputs = read_file("input", FoodEntry)

    end

    def read_file name, klass
        result = []
        file = @config_dir+name
        FileUtils.touch(file)
        IO.readlines(file).each do |line|
            next if line == "\n"
            result << klass::from_line(line)
        end
        result.sort_by{|e| e.date}
    end

    def status
        kg_lost = moving_average_at(start_date) - moving_average_at(end_date)
        puts "#{kg_lost.round(1)} kg down (#{(100*kg_lost/(kg_lost+kg_to_go)).round}%), #{kg_to_go.round(1)} kg to go!"
        log_since(Date.today - 1)
    end

    def log
        log_since(start_date)
    end

    def weight date, weight
        @weights << WeightEntry.new(date, weight)
        write_weights
        plot
    end

    def nom date, kcal, description
        kcal = calculate(kcal)
        @inputs << FoodEntry.new(date, kcal, description)
        write_inputs
    end

    def search term
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
                points = quantize(kcal)

                #next if size =~ /100 g/

                #puts "    (#{points})#{points>9 ? "" : " "} #{size}"
                puts "    (#{points}) #{size}"
            end
        end
    end

    def plot
        dat = ""
        (start_date).upto(end_date) do |date|
            dat << "#{date}\t#{weight_at(date)}\t#{moving_average_at(date)}\t#{quantize(allowed_kcal(date))}\t#{quantize(consumed_at(date))}\n"
        end

        plt = <<HERE
set terminal svg size 1440,900 font "Linux Biolinum,20"
set output "/tmp/nom.svg"

set multiplot layout 2,1

set border 11

set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m"
set grid
set lmargin 6

set xrange [ "#{start_date}" : "#{Date.today+days_to_go}" ]
set yrange [ #{@goal} : #{@weights.map{|w| w.weight}.max.ceil} ]
set ytics 1 nomirror
set mxtics 1
set xtics 2592000 nomirror

set obj 1 rectangle behind from screen 0,0 to screen 1,1
set obj 1 fillstyle solid 1.0 fillcolor rgb "white"

plot '/tmp/nom.dat' using 1:2 w points t 'Weight' pt 13 ps 0.3 lc rgb "navy", \
'/tmp/nom.dat' using 1:3 w l t '' lt 1 lw 2 lc rgb "navy", \
#{moving_average_at(start_date+@skip_first)}-#{@rate}*(x/60/60/24/7-#{(start_date+@skip_first-Date.parse("2000-01-01"))/7.0}) t '#{(@rate).round(1)} kg/week' lc rgb "forest-green"

unset obj 1

set yrange [ 0 : #{quantize((start_date..end_date).map{|d| consumed_at(d)}.max)} ]
set ytics 200 nomirror

plot '/tmp/nom.dat' using 1:4 w histeps t 'Allowed energy' lc rgb "black", \
'/tmp/nom.dat' using 1:5 w histeps t 'Consumed energy'

unset multiplot
HERE

        File.write("/tmp/nom.dat", dat)
        File.write("/tmp/nom.plt", plt)
        system("gnuplot /tmp/nom.plt")
        system("eog -f /tmp/nom.svg")
    end

    def edit
        editor = ENV["EDITOR"]
        editor = "vim" if editor.nil?
        system("#{editor} #{ENV["HOME"]}/.nom/input")
    end

    private

    def allowed_kcal d
        allowed = @weights.first.weight*25*1.2 - @rate*1000
        adapt_every = 28 # days
        i = -1
        skipped_first_block = false
        start_date.upto(d) do |date|
            i += 1
            if not skipped_first_block
                if i == @skip_first
                    skipped_first_block = true
                    i = 0
                end
                next
            end
            if i == adapt_every
                weight_before = moving_average_at(date-adapt_every)
                weight_now = moving_average_at(date)
                loss = weight_before - weight_now
                intake = 0
                (date-adapt_every).upto(date-1) do |d|
                    intake += consumed_at(d)
                end
                kcal_per_kg_body_fat = 7000
                burned_kcal_per_day = loss*kcal_per_kg_body_fat/adapt_every
                wanted_to_burn_per_day = @rate*1000
                burned_too_little = wanted_to_burn_per_day - burned_kcal_per_day
                intake_per_day = intake/adapt_every
                allowed = intake_per_day - burned_too_little
                i = 0
            end
        end
        allowed
    end

    def weight_at date
        w = @weights.select{|w| w.date == date }
        if w.empty?
            prev_weight = @weights.select{|w| w.date < date }.max_by{|w| w.date}
            next_weight = @weights.select{|w| w.date > date }.min_by{|w| w.date}
            raise "todo" if next_weight.nil?
            prev_weight.weight + (prev_weight.weight-next_weight.weight)/(prev_weight.date-next_weight.date)*(date-prev_weight.date)
        else
            w.first.weight
        end
    end

    def consumed_at date
        @inputs.select{|i| i.date == date }.inject(0){ |sum, i| sum+i.kcal }
    end

    def moving_average_at date
        alpha = 0.1
        beta = 0.1
        average = weight_at(start_date)
        trend = -@rate/7.0
        (start_date+1).upto(date) do |d|
            last_average = average
            average = alpha*weight_at(d) + (1-alpha)*(average+trend)
            trend = beta*(average-last_average) + (1-beta)*trend
        end
        average
    end

    def write_weights
        open(@config_dir+"weight", "w") do |f|
            @weights.each do |e|
                f << e.to_s
            end
        end
    end

    def write_inputs
        open(@config_dir+"input", "w") do |f|
            last_date = @inputs.first.date
            @inputs.each do |e|
                if last_date < e.date
                    f << "\n"
                end
                f << e.to_s
                last_date = e.date
            end
        end
    end

    def current_weight
    end

    def kg_to_go
        moving_average_at(end_date) - @goal
    end

    def kcal_to_burn
        kcal_per_kg_body_fat = 7000
        kg_to_go * kcal_per_kg_body_fat
    end

    def days_to_go
        kcal_to_burn/(@rate*1000)
    end

    def start_date
        [@inputs.first.date, @weights.first.date].min
    end

    def end_date
        @weights.last.date
    end

    def goal_date
        Date.today + days_to_go
    end

    def quantize kcal
        return (kcal/@unit).round
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

    def calculate term
        factors = term.split("x")
        product = factors.map{ |f| f.to_f }.inject(1){ |p,f| p*f }
        if product == 0
            raise "kcal term cannot be zero"
        end
        return product
    end

    def log_since start
        remaining = 0
        start_date.upto(end_date) do |date|
            show = date >= start
            remaining += allowed_kcal(date)
            if show
                puts
                puts "#{format_date(date)}: (#{quantize(remaining)}) of (#{quantize(allowed_kcal(date))})"
                puts
            end
            @inputs.select{|i| i.date == date }.each do |i|
                if show
                    puts "#{" "*(6-quantize(i.kcal).to_s.length)}(#{quantize(i.kcal)}) #{i.description}"
                end
                remaining -= i.kcal
            end
            if show
                puts "---------------------"
                puts "#{" "*(6-quantize(remaining).to_s.length)}(#{quantize(remaining)}) remaining"
            end
        end
    end
end
