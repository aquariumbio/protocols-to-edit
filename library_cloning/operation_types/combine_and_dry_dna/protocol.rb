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
needs 'Cloning Libs/Cloning'

class Protocol

    include LibraryCloningHelper
    include PurificationHelper
    include Cloning

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
            # check the volumes of samples for all operations, and ensure they are sufficient
            operations.each { |op| op.temporary[:vol_P] = 1000*op.input(QUANTITY_P).val }
            check_volumes [INPUT_P], :vol_P, :not_enough_input, check_contam: true
            operations.each { |op| op.temporary[:vol_F] = 1000*op.input(QUANTITY_F).val }
            check_volumes [INPUT_F], :vol_F, :not_enough_input, check_contam: true
        end

        # error operations with too little material
        show do
            ops=operations.running
            operations=ops
            if(operations.length<1)
                note "No operations running! Returning."
                return
            end
        end

        show do
            title "Label tubes"
            ids = operations.map { |op| op.output(OUTPUT).item.id}
            check "Label empty tubes for the combined samples: <b>#{ids.to_sentence}</b>"
        end

        # combine correct volumes
        show do
            title "Label tubes and add insert DNA"
            warning "Be careful not to make mistakes! Work one row at a time"
            check "Vortex Plasmid and Insert briefly and spin down before combining"
            check "Combine the indicated volumes of the inputs into the indicated output tube(s):"
        end

        # add plasmid backbone
        show do
            title "Add plasmid backbone"
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

        # still not concentrated enough
        if( (nloops>=TRIES) && (unfinished.length > 1) )
            show do
                title "Problem!"
                note "#{TRIES} rounds of concentration not enough for samples <b>#{unfinished.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b>! Please check with a lab manager."
            end
        end

        operations.each { |op|
            op.output(OUTPUT).item.associate :final_volume, op.temporary[:final_volume]
            op.output(OUTPUT).item.move_to("M20")
        }

        out_items=operations.map{|op| op.output(OUTPUT).item}
        release(out_items, interactive: true, method: "boxes")

        return {}

    end # main

    # This method takes inputs and tells the technician to discard any contaminated DNA stock items.
    def not_enough_input(bad_ops_by_item, inputs)
        if bad_ops_by_item.keys.select { |item| item.get(:contaminated) == 'Yes' }.any?
            show do
                title 'discard contaminated DNA'

                note "discard the following contaminated DNA stock items: #{bad_ops_by_item.keys.select { |item| item.get(:contaminated) == 'Yes' }.map(&:id).to_sentence}"
            end
        end

        show do
            bad_ops_by_item.each do |item, _ops|
                warning "Sample #{item.id} doesn't have enough volume. This operation has been pushed to error, please notify a lab manager."
                bad_ops_by_item[item].each { |op| op.error :not_enough_volume, "Sample #{item.id} doesn't have enough volume. This operation has been pushed to error, please notify a lab manager." }
                bad_ops_by_item.except! item
                item.mark_as_deleted if item.get(:contaminated) == 'Yes'
            end
        end
    end

end # Protocol
