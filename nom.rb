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

        weight_file = @config_dir+"weight"
        FileUtils.touch(weight_file)
        IO.readlines(weight_file).each do |line|
            @weights << WeightEntry::from_line(line)
        end
        @weights.sort_by{|e| e.date}

        input_file = @config_dir+"input"
        FileUtils.touch(input_file)
        IO.readlines(input_file).each do |line|
            @inputs << FoodEntry::from_line(line)
        end
        @inputs.sort_by{|e| e.date}
    end

    def status
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
        moving_average = @weights.first.weight
        last_date = @weights.first.date
        last_weight = @weights.first.weight
        beta = 0.90
        @weights.each do |e|
            while e.date > last_date + 1
                last_weight = last_weight + (last_weight-e.weight)/(last_date-e.date)
                moving_average = beta*moving_average + (1-beta)*last_weight
                dat << "#{last_date+1}\t0\t#{moving_average}\n"
                last_date += 1
            end
            moving_average = beta*moving_average + (1-beta)*e.weight
            dat << "#{e.date}\t#{e.weight}\t#{moving_average}\n"
            last_date = e.date
            last_weight = e.weight
        end

        plt = <<HERE
#set title "Fu"

set border 11

set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m"

set xrange [ "#{@weights.first.date}" : "#{Date.today+days_to_go}" ]
set yrange [ #{@goal-1} : #{@weights.map{|w| w.weight}.max+0.5} ]
set grid

set ytics 1
set mxtics 4
set xtics nomirror
set samples 300

set terminal svg size 1920,700 font "Linux Biolinum,20"
set output "/tmp/nom.svg"

set obj 1 rectangle behind from screen 0,0 to screen 1,1
set obj 1 fillstyle solid 1.0 fillcolor rgb "white"

plot '/tmp/nom.dat' using 1:2 w points t 'Weight' pt 13 ps 0.3 lc rgb "navy", \
'/tmp/nom.dat' using 1:3 w l t sprintf("Moving average λ=%1.2f",#{beta}) lt 1 lw 2 lc rgb "navy", \
(#{@goal}) w l t 'Target' lw 2 lt 1, \
#{@weights.first.weight}-#{@rate}*(x/60/60/24/7-#{(@weights.first.date-Date.parse("2000-01-01"))/7.0}) t '#{(@rate).round(1)} kg/week' lc rgb "forest-green"
HERE

        File.write("/tmp/nom.dat", dat)
        File.write("/tmp/nom.plt", plt)
        system("gnuplot /tmp/nom.plt")
        system("eog /tmp/nom.svg")
    end

    private

    def allowed_kcal d
        allowed = @weights.first.weight*25*1.2 - @rate*1000
        adapt_every = 7 # days
        i = -1
        start_date.upto(d) do |date|
            i += 1
            if i == adapt_every
                weight_before = weight_at(date-adapt_every)
                weight_now = weight_at(date)
                loss = weight_before - weight_now
                kcal_per_kg_body_fat = 7000
                burned_kcal_per_day = loss*kcal_per_kg_body_fat/adapt_every
                wanted_to_burn_per_day = @rate*1000
                burned_too_little = wanted_to_burn_per_day - burned_kcal_per_day
                allowed = allowed - burned_too_little
                i = 0
            end
        end
        allowed
    end

    def weight_at date
        w = @weights.select{|w| w.date == date }
        if w.empty?
            raise "todo"
        else
            w.first.weight
        end
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
            @inputs.each do |e|
                f << e.to_s
            end
        end
    end

    def current_weight
        @weights.last.weight
    end

    def kg_to_go
        current_weight - @goal
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
        Date.today + days_to_go
    end

    def quantize kcal
        return (kcal/@unit).round
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
        start_date.upto(Date.today) do |date|
            show = date >= start
            remaining += allowed_kcal(date)
            if show
                puts date
                puts "    Available: (#{quantize(remaining)}) of (#{quantize(allowed_kcal(date))})"
            end
            @inputs.select{|i| i.date == date }.each do |i|
                if show
                    puts "    (#{quantize(i.kcal)}) #{i.description}"
                end
                remaining -= i.kcal
            end
            if show
                puts "    Remaining: (#{quantize(remaining)})"
            end
        end
    end
end
