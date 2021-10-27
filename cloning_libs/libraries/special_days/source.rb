# Garrett 8-15-17

module SpecialDays
    def give_happy_birthday
        birthdays = {
            "1-3" => "Eddie",
            "2-4" => "Aidan",
            "2-18" => "Sam",
            "3-1" => "Cami",
            "4-10" => "Halie",
            "9-30" => "Luana",
            "11-23" => "Sophia",
            "12-13" => "Maggie"
        }
        balloon = "&#127880;"
        confetti = "&#127882;"
        
        birthdays.each do |date, name|
            # TODO add more things to do
            thing_to_do = [
                "a big hug or awesome high-five",
                "a piece of dry ice in a falcon tube! Slip it into their back pocket for a birthday suprise",
                "a free lunch",
                "some beautiful flowers",
                "the day off",
                "a really cool starwars themed lego set"
            ].sample
                
            show do
                title "#{balloon}#{confetti}#{balloon}HAPPY BIRTHDAY TO #{name.upcase}!!!#{balloon}#{confetti}#{balloon}"
                
                check "Give #{name} #{thing_to_do}. :)"
            end if Date.today.to_s.include? date
        end
    end
end