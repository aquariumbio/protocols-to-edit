# Devin Strickland
# dvn.strcklnd@gmail.com
# SG modified so batchable
#
# Baker protocol:
# Combine 2 g linearized petcon vector and 4 g amplified library (combined or single sublibraries, depending on user) in 1.5 mL eppendorf.
# Concentrate using SpeedVac for ~2 hours, until DNA volume is less than 30 L. Drier is better! 
# Store concentrated DNA in eppendorf on ice on bench while you prepare the cells.
# Notes: This can be done in advance. Store eppendorf containing DNA in -20C if concentrated ahead of time.
needs "Library Cloning/LibraryCloningHelper" # for concentrateSample
needs "Library Cloning/PurificationHelper"
 
class Protocol
    
    include LibraryCloningHelper
    include PurificationHelper
    
    # I/O
    INPUT_P="Plasmid" 
    INPUT_F="Insert"
    QUANTITY_P="Plasmid micrograms"
    QUANTITY_F="Insert micrograms"
    OUTPUT="Dried DNA" # in 1.5mL tube
     
    # other
    MAX_VOL=30 # uL, maximum volume for DNA in transformation step
    TRIES=3 # up to 3 rounds of concentration 
    HEAT_LEVEL="MED"  
    TIME={hr: 0, min: 30, sec: 0} # hr   
  
    def main

        # make output item
        operations.retrieve.make
        
        # get concentrations if not already associated
        measureConcentration("in",INPUT_P,operations)
        measureConcentration("in",INPUT_F,operations)
        
        # invent concentrations in debug mode
        if (debug)
            operations.each { |op|
                if(op.input(INPUT_P).item.get(:concentration).nil?)
                    op.input(INPUT_P).item.associate :concentration, '100.0'
                end
                if(op.input(INPUT_F).item.get(:concentration).nil?)
                    op.input(INPUT_F).item.associate :concentration, '200.0'
                end
            }
        end
        
        # get input volumes
        show do
            title "Estimate initial volumes of samples" 
            note "If there is insufficient volume of the samples the operation will terminate"
            table operations.start_table
              .input_item(INPUT_P)
              .get(:vol_P, type: 'number', heading: "Plasmid Volume (ÂµL)", default: 0)
              .input_item(INPUT_F)
              .get(:vol_F, type: 'number', heading: "Insert Volume (ÂµL)", default: 0)
              .end_table 
        end 
         
        # error operations with too little material
        if(!debug)
            operations.each { |op|
                if(op.temporary[:vol_P].to_f*(op.input(INPUT_P).item.get(:concentration).to_f) < 1000*op.input(QUANTITY_P).val)
                    show { 
                        note "#{op.temporary[:vol_P].to_f*(op.input(INPUT_P).item.get(:concentration).to_f)} < #{1000*op.input(QUANTITY_P).val}" 
                        note "op.temporary[:vol_P].to_f=#{op.temporary[:vol_P]}"
                        note "op.input(INPUT_P).item.get(:concentration).to_f=#{op.input(INPUT_P).item.get(:concentration)}"
                    }
                    op.error :not_enough_plasmid, "There was not enough volume of plasmid #{op.input(INPUT_P).item} for this Combine and Dry DNA operation." 
                elsif(op.temporary[:vol_F].to_f*(op.input(INPUT_F).item.get(:concentration).to_f) < 1000*op.input(QUANTITY_F).val)
                    op.error :not_enough_insert, "There was not enough volume of insert #{op.input(INPUT_F).item} for this Combine and Dry DNA operation." 
                end 
            }
        end
        ops=operations.running
        operations=ops
        if(operations.length<1)
            show { note "No operations running! Returning."} 
            return
        end
        
        # prep tubes for speedvac
        prep_speedvac_tubes(operations.map { |op| op.output(OUTPUT).item.id}, MAX_VOL)
        
        # combine correct volumes
        show do
            title "Combine plasmids and backbones"
            warning "Be careful not to make mistakes! Work one row at a time"
            check "Vortex Plasmid and Insert briefly and spin down before combining"
            check "Combine the indicated volumes of the inputs into the indicated output tube(s):"
            table operations.start_table
              .output_item(OUTPUT)
              .input_item(INPUT_P)
              .custom_column(heading: "Plasmid volume (ÂµL)", checkable: true) { |op| (op.input(QUANTITY_P).val.to_f*1000/op.input(INPUT_P).item.get(:concentration).to_f).round(2) }
              .input_item(INPUT_F)
              .custom_column(heading: "Insert volume (ÂµL)", checkable: true) { |op| (op.input(QUANTITY_F).val.to_f*1000/op.input(INPUT_F).item.get(:concentration).to_f).round(2) } 
              .end_table
            check "Vortex all combined samples briefly and spin down"  
        end
        
        # associate initial combined volume
        operations.each { |op|
            vol = op.input(QUANTITY_P).val.to_f*1000/op.input(INPUT_P).item.get(:concentration).to_f
            vol = vol + op.input(QUANTITY_F).val.to_f*1000/op.input(INPUT_F).item.get(:concentration).to_f
            op.output(OUTPUT).item.associate :init_volume, vol.round(2)
        }
        
        # dry samples. repeat for up to TRIES concentration steps (to avoid endless loop)
        nloops=0
        unfinished=operations.select { |op| op.output(OUTPUT).item.get(:init_volume) > MAX_VOL }
        finished=operations.select { |op| op.output(OUTPUT).item.get(:init_volume) <= MAX_VOL }
        
        # associate the (null) concentrating conditions for the samples that do not need concentrating 
        finished.each { |op|
            op.output(OUTPUT).item.associate :concentration_heat_level, "none"
            op.output(OUTPUT).item.associate :concentration_time, "none"
        }
        
        # return items to freezer before going to speedvac
        in_items=[operations.map{|op| op.input(INPUT_P).item}, operations.map{|op| op.input(INPUT_F).item}].flatten
        release(in_items, interactive: true, method: "boxes")
        
        loop do
            nloops=nloops+1
            break if ( (nloops>TRIES) or (unfinished.empty?) ) # stopping condition
                    
            # concentrate. timer is set inside function.
            concentrateSample(unfinished.map { |op| op.output(OUTPUT).item.id}, HEAT_LEVEL, TIME) # id, heat_level, time_hrs
                
            # estimate volume
            estimateVolumes(unfinished, "out", OUTPUT, MAX_VOL, nloops)
            
            unfinished = operations.select { |op| ['Y','y'].include? op.temporary[:high_vol] }
            finished = operations.select { |op| !(['Y','y'].include? op.temporary[:high_vol]) } 
            
            # associate concentrating conditions and new volume 
            finished.each { |op|
                op.output(OUTPUT).item.associate :concentration_heat_level, HEAT_LEVEL
                op.output(OUTPUT).item.associate :concentration_time, nloops*(TIME[:hr]*60+TIME[:min]) # total time 
            }
            
            # instructions
            if(unfinished.length > 1)
                show do
                    title "Place concentrated samples aside"
                    check "Place tube(s) <b>#{finished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b> on ice"
                    note "The remaining samples <b>#{unfinished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b> will need another round of drying"
                end
            else 
                show do
                    title "Place concentrated samples aside"
                    check "Place tube(s) <b>#{finished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b> on ice"
                end
            end
            
        end # loop
        
        # still not concentrated enough
        if( (nloops>=TRIES) && (unfinished.length > 1) )
            show do
                title "Problem!"
                note "#{TRIES} rounds of concentration not enough for samples <b>#{unfinished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b>! Please check with a lab manager."
            end
        end
        
        # measure final volume
        show do
            title "Measure final volume of combined sample"
            check "Zero scale using an empty 1.5 mL eppendorf tube"
            note "Weigh combined samples <b>#{finished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b> and enter volumes into the following table (1mg=1ÂµL):"
            table operations.start_table
                .output_item(OUTPUT)
                .get(:final_volume, type: 'number', heading: "Final Volume (ÂµL)", default: 0) 
                .end_table
        end
        
        operations.each { |op|    
            op.output(OUTPUT).item.associate :final_volume, op.temporary[:final_volume]
            op.output(OUTPUT).item.move_to("M20")
        } 
        
        out_items=operations.map{|op| op.output(OUTPUT).item}
        release(out_items, interactive: true, method: "boxes")
        
        return {}
        
    end # main

end # Protocol
