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

        # if it doesn't have a concentration, nanodrop them
        operations.each { |op|
            if(op.input(INPUT_P).item.get(:concentration).nil?)
                measure_plasmid_stock(INPUT_P, [op])
            end
            if(op.input(INPUT_F).item.get(:concentration).nil?)
                measure_plasmid_stock(INPUT_F, [op])
            end
        }

        # check the volumes of samples for all operations, and ensure they are sufficient
        operations.each { |op| op.temporary[:vol_P] = 1000*op.input(QUANTITY_P).val }
        check_volumes [INPUT_P], :vol_P, :not_enough_input, check_contam: true
        operations.each { |op| op.temporary[:vol_F] = 1000*op.input(QUANTITY_F).val }
        check_volumes [INPUT_F], :vol_F, :not_enough_input, check_contam: true

        # error operations with too little material
        ops=operations.running
        operations=ops
        if(operations.length<1)
            show do
                note "No operations running! Returning."
            end
            return
        end

        # label tubes and combine correct volumes
        show do
            title "Label tubes and add insert DNA"
            ids = operations.map { |op| op.output(OUTPUT).item.id}
            # if ids is not an array, make it one
            if(!ids.kind_of?(Array))
                ids = [ids]
            end
            warning "Be careful not to make mistakes! Work one row at a time"
            check "Label empty tubes for the combined samples: <b>#{ids.to_sentence}</b>"
            check "Vortex Plasmid and Insert briefly and spin down before combining"
            check "Combine the indicated volumes of the inputs into the newly labeled tubes"
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

        # return items to freezer
        in_items=[operations.map{|op| op.input(INPUT_P).item}].flatten
        release(in_items, interactive: true, method: "boxes")

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

    # takes in array of operations and asks the technician
    # to measure the concentrations of the input items.
    #
    # @param input [String] the input that needs to be nanodropped
    # @param ops_for_measurement [Array] the ops that contain the items we are measuring
    def measure_plasmid_stock(input, ops_for_measurement)
        if ops_for_measurement.any?
            conc_table = Proc.new { |ops|
                ops.start_table
                .input_item(input)
                .custom_input(:concentration, heading: "Concentration (ng/ul)", type: "number") { |op|
                    x = op.temporary[:concentration] || -1
                    x = rand(10..100) if debug
                    x
                }
                .validate(:concentration) { |op, v| v.between?(0,10000) }
                .validation_message(:concentration) { |op, k, v| "Concentration must be non-zero!" }
                .end_table.all
        }

        show_with_input_table(ops_for_measurement, conc_table) do
            title "Measure concentrations"
            note "The concentrations of some plasmid stocks are unknown."
            check "Go to the nanodrop and measure the concentrations for the following items."
            check "Write the concentration on the side of each tube"
        end

        ops_for_measurement.each do |op|
            op.input(input).item.associate :concentration, op.temporary[:concentration]
        end
        end
    end

end # Protocol
