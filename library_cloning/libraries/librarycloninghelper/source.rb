# SG
# helper functions for library cloning
module LibraryCloningHelper
     
    BELONGS_TO="Baker"
    
    #---------------------------------------------------------------------
    # estimate volumes before/after speedvac, based on line drawn on tube.
    # ops - list of ops for whom we are estimating volume
    # ioStr - input/output item (for sample id)
    # ioOrOut - one of 'in','out'
    # nloops - integer, speedvac round
    #---------------------------------------------------------------------
    def estimateVolumes(ops, inOrOut, ioStr, max_vol, nloops)
        
        samples=''
        tab=[]
        
        case inOrOut
            when 'in'
                samples=ops.map { |op| op.input(ioStr).item.id}.to_sentence 
                tab = ops.start_table
                    .input_item(ioStr)
                    .custom_input(:high_vol, heading: "Contains more than #{max_vol} ÂµL ?", type: "string") {|op| op.temporary[:high_vol] || 'N'}
                    .end_table
            when 'out'
                samples=ops.map { |op| op.output(ioStr).item.id}.to_sentence 
                tab = ops.start_table
                    .output_item(ioStr)
                    .custom_input(:high_vol, heading: "Contains more than #{max_vol} ÂµL ?", type: "string") {|op| op.temporary[:high_vol] || 'N'}
                    .end_table
        end
        
        show do
            title "Estimate volume of combined samples (round #{nloops})"
            note "For sample(s) <b>samples</b>, enter <b>Y</b> if sample is over #{max_vol} ÂµL (indictaed by black line on tube):"
            table tab
            note "If there is no line on the tube, compare to #{max_vol} ÂµL in an empty tube (labeled <b>MG</b>)"
        end
    end
     
    #---------------------------------------------------------------------
    # prep samples for Speedvac concentrating
    # ids - ids of items to be concentrated (single item or array)
    #---------------------------------------------------------------------
    def prep_speedvac_tubes(ids,max_vol)
        
        # if ids is not an array, make it one
        if(!ids.kind_of?(Array))
            ids=[ids]
        end
        
        # prepare tubes
        show do
            title "Prepare tubes for samples to be concentrated"
            check "Grab #{ids.length + 1} 1.5 mL tubes"
            check "Transfer #{max_vol} ÂµL of MG water into one of the tubes and mark its lid <b>MG</b>"
            check "Label empty tubes for the combined samples: <b>#{ids.to_sentence}</b>"
            check "Mark the #{max_vol} ÂµL level of the labeled tubes (using a sharpee) by comparison to the tube labeled <b>MG</b>"
            if(!(ids.length.to_i.even?))
                check "Get an empty 1.5mL eppendorf and label its lid <b>X</b>. This will be used as a balance."
                check "Add an volume of MG water equal to the volume of sample <b>#{ids[0]}</b> to the 1.5mL eppendorf marked <b>X</b>"
            end
        end
        
    end
    
    #---------------------------------------------------------------------
    # use Speedvac to concentrate sample 
    # inputs:
    # ids - ids of items to be concentrated (single item or array)
    # heat_level - "LOW"/"MED" (default)/"HIGH". low=room T, med = 45C, high=63C.
    # time - hash of {hr: , min: , sec: } - how long to run Speedvac (hrs)
    #---------------------------------------------------------------------
    def concentrateSample(ids, heat_level, time)
        
        # if ids is not an array, make it one
        if(!ids.kind_of?(Array))
            ids=[ids]
        end
        
        # find heating level
        case heat_level
        when "LOW","MED","HIGH" # all ok, do nothing
        else 
            show do 
                title "Heating setting"
                note "Heating setting input is not an allowed value (LOW/MED/HIGH), defaulting to MED=45C."
            end
            heat_level="MED"
        end
        
        # run speedvac
        show do 
            title "Concentrate sample(s)"
            note "You will be using the #{BELONGS_TO} lab's Speedvac  to concentrate the sample. Note the Speedvac settings below, and go to the #{BELONGS_TO} lab."
            #warning "Ask permission from a member of the #{BELONGS_TO} lab before using the Speedvac!"
            check "Open sample(s) <b>#{ids.to_sentence}</b> (and balance <b>X</b> if needed) eppendorf tubes"
            check "Open the Speedvac lid. Place sample(s) <b>#{ids.to_sentence}</b> and the balance marked <b>X</b> at opposing positions in the centrifuge"
            warning "Make sure the samples are balanced properly!"
            check "Lower the Speedvac lid"
            check "Set the concentrator button on the front panel to <b>ON</b>"
            check "Set the heating level on the front panel to <b>#{heat_level}</b>"
            check "Turn on the centrifuge (power button is on front right side of machine)"
            if(BELONGS_TO=="Baker lab")
                note "If the centrifuge does not start turning, turn off pump. Slide clear plastic lid on centrifuge forward (on right side). Restart pump."
            end
            check "Turn on the pump (green button next to display behind machine). Make sure numbers are decreasing!"
        end
        
        show do
            title "Set timer"
            timer initial: { hours: time[:hr], minutes: time[:min], seconds: [:sec]}
            note "When timer finishes, go back to #{BELONGS_TO} lab and turn off pump by pressing <b>TWICE</b> on red button"
            note "Wait till pressure reaches about 1000 mbar"
            note "Turn off centrifuge and heater (black buttons on front panel of Speedvac)" 
            warning "Remember to collect sample and turn off Speedvac (right side of machine) when timer finishes!" 
        end
        
    end # concentrateSample
    
end # module
