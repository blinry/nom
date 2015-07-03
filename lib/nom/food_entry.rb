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
