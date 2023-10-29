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
end
