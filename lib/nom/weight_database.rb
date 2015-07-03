require "yaml"
require "fileutils"

class WeightDatabase
    def initialize(file)
        @interpolated = {}
        @weights = {}
        @moving_averages = {}

        FileUtils.touch(file)
        IO.readlines(file).each do |line|
            date, weight = line.split(" ", 2)
            date = Date.parse(date)
            @weights[date] = weight.to_f
            @interpolated[date] = false
        end
    end

    def interpolate_gaps!
        dates.each_cons(2) do |a, b|
            (a+1).upto(b-1) do |d|
                @weights[d] = @weights[a] + (@weights[a]-@weights[b])/(a-b)*(d-a)
                @interpolated[d] = true
            end
        end
    end

    def precompute_moving_average!(alpha, beta, rate)
        trend = -rate/7.0

        @moving_averages[min] = at(min)
        (min+1).upto(max).each do |d|
            @moving_averages[d] = alpha*at(d) + (1-alpha)*(@moving_averages[d-1]+trend)
            trend = beta*(@moving_averages[d]-@moving_averages[d-1]) + (1-beta)*trend
        end
    end

    def predict_weights!(rate, goal, tail)
        d = (max+1)
        while @weights[d-tail].nil? or @weights[d-tail] > goal+0.001
            prev_weight = @moving_averages[d-1] || @weights[d-1]
            @weights[d] = prev_weight+dampened_rate(prev_weight, goal, rate)/7.0
            @interpolated[d] = true
            d += 1
        end
    end

    def dampened_rate weight, goal, rate
        r = (goal-weight).to_f
        if r.abs > 1
            r/r.abs*rate
        else
            r*rate
        end
    end

    def interpolated_at? date
        @interpolated[date]
    end

    def at date
        @weights[date]
    end

    def moving_average_at date
        @moving_averages[date]
    end

    def rate_at date, goal, rate
        if date > last_real_date
            dampened_rate(@weights[date], goal, rate)
        else
            dampened_rate(@moving_averages[date], goal, rate)
        end
    end

    def dates
        @weights.keys
    end

    def weights
        @weights.values
    end

    def empty?
        @weights.empty?
    end

    def min
        dates.min
    end

    def max
        dates.max
    end

    def last_real_date
        @interpolated.select{|d, i| not i}.keys.max
    end

    def truncate date
        @weights.delete_if{|d, w| d < date}
    end
end
