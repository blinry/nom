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
        @weights.keys.each_cons(2) do |a, b|
            (a+1).upto(b-1) do |d|
                @weights[d] = @weights[a] + (@weights[a]-@weights[b])/(a-b)*(d-a)
                @interpolated[d] = true
            end
        end
    end

    def precompute_moving_average!(alpha, beta, goal, rate)
        trend = dampened_rate(@weights[first], goal, rate)/7.0

        @moving_averages[first] = at(first)
        (first+1).upto(last).each do |d|
            @moving_averages[d] = alpha*at(d) + (1-alpha)*(@moving_averages[d-1]+trend)
            trend = beta*(@moving_averages[d]-@moving_averages[d-1]) + (1-beta)*trend
        end
    end

    def predict_weights!(rate, goal, tail)
        d = (last)
        loop do
            if (@weights[d] - goal).abs < 0.1
                tail -= 1
            end
            if tail == 0
                break
            end

            d += 1
            prev_weight = @moving_averages[d-1] || @weights[d-1]
            @weights[d] = prev_weight+dampened_rate(prev_weight, goal, rate)/7.0
            @interpolated[d] = true
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

    def real? date
        @weights[date] and not @interpolated[date]
    end

    def at date
        @weights[date]
    end

    def moving_average_at date
        @moving_averages[date]
    end

    def rate_at date, goal, rate
        if date > last_real
            dampened_rate(@weights[date], goal, rate)
        else
            dampened_rate(@moving_averages[date], goal, rate)
        end
    end

    def empty?
        @weights.empty?
    end

    def first
        @weights.keys.min
    end

    def last
        @weights.keys.max
    end

    def last_real
        @interpolated.select{|d, i| not i}.keys.max
    end

    def truncate date
        @weights.delete_if{|d, w| d < date}
    end

    def min
        @weights.values.min
    end

    def max
        @weights.values.max
    end

    def find_gap days
        gap = @weights.keys.reverse.each_cons(2).find{|a,b| a-b > days}
        if gap
            gap.reverse
        else
            nil
        end
    end
end
