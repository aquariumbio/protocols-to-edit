# SG
# code adapted from Cloning/Purify Gel Slice
# helper functions for purification of a fragment from either gel slice or liquid-based reactions (e.g., PCR, restriction)
#
# careful when editing! used by the following Protocols:
# Purify on Column
# Purify Gel Slice
# Purify High-Volume Gel
module PurificationHelper

    # TODO refactor density parameter name? (see qg_volumes and iso_volumes definitions)
    DENSITY1 = 1.0 / 3000.0
    DENSITY2 = 1.0 / 1000.0
    MAX_VOL = 750 # uL, max volume to load on 1.5 eppi
    TEMP_BLOCK = "H2" # whick block to use
    TEMP_BLOCK_T = 40 # C

    # common to both kits - appear separately in settings, but can be changed here for both
    SPIN_G=17 # g
    SPIN_TIME_MIN=1 # min
    ELUTION_TEMP_C=50 # degrees
    ELUTION_VOL=30 # uL
    ELUTION_TIME_MIN=5 # min
    FIRST_RINSE_VOL = 750 # uL
    SECOND_RINSE_VOL = 500 # uL
    LOAD_TIME = 1 # min

    # allowed kits and their settings
    QIAGEN_SETTINGS={"column" => "blue Qiagen column", "loadingBuffer"=> "Qiagen QG buffer", "washBuffer" => "Qiagen PE buffer", "elutionBuffer" => "Qiagen EB buffer", "elutionTemperature" => 50, "elutionVolume" => ELUTION_VOL, "spinG" => SPIN_G, "spinTime" => SPIN_TIME_MIN, "elutionTime" => ELUTION_TIME_MIN, "meltTime" => 10, "meltTemperature" => 50, "firstRinseVol" => FIRST_RINSE_VOL, "secondRinseVol" => SECOND_RINSE_VOL, "loadingTime" => LOAD_TIME}
    QIAGENPINK_SETTINGS={"column" => "pink Qiagen column", "loadingBuffer"=> "Qiagen QG buffer", "washBuffer" => "Qiagen PE buffer", "elutionBuffer" => "Qiagen EB buffer", "elutionTemperature" => 50, "elutionVolume" => ELUTION_VOL, "spinG" => SPIN_G, "spinTime" => SPIN_TIME_MIN, "elutionTime" => ELUTION_TIME_MIN, "meltTime" => 10, "meltTemperature" => 50, "firstRinseVol" => FIRST_RINSE_VOL, "secondRinseVol" => SECOND_RINSE_VOL, "loadingTime" => LOAD_TIME}
    PROMEGA_SETTINGS={"column" => "Promega column", "loadingBuffer"=> "Membrane Binding Solution", "washBuffer" => "Membrane Wash Solution", "elutionBuffer" => "molecular grade water", "elutionTemperature" => 50, "elutionVolume" => ELUTION_VOL, "spinG" => SPIN_G, "spinTime" => SPIN_TIME_MIN, "elutionTime" => ELUTION_TIME_MIN, "meltTime" => 5, "meltTemperature" => 50, "firstRinseVol" => FIRST_RINSE_VOL, "secondRinseVol" => SECOND_RINSE_VOL, "loadingTime" => LOAD_TIME}
    KIT_SETTINGS={"Qiagen"=>QIAGEN_SETTINGS,"QiagenPink"=>QIAGENPINK_SETTINGS,"Promega"=>PROMEGA_SETTINGS}


    #---------------------------------------------------------------------
    # load sample on column
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def findSettings(kitStr)
        kit=KIT_SETTINGS.fetch(kitStr)
        if(kit.nil?)
            show do
                title "Problem!"
                note "Purification kit #{kitStr} not recognized, exiting."
                return
            end
        end
        # return settings
        kit
    end # def

    #---------------------------------------------------------------------
    # heat elution buffer
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def heatElutionBuffer(ioStr, kitStr)

        kit=findSettings(kitStr)

        tot_reactions = 0
        operations.each { |op|
            if(op.input(ioStr).object_type.name=="Multiple Gel Slices")
                tot_reactions = tot_reactions + op.input(ioStr).item.get(:number_of_tubes).to_f
            else
                tot_reactions = tot_reactions + 1
            end
        }

        show do
            title "Preheat elution buffer"
            # math: 1.5 so there is spare, 2 because we may split into 2 tubes
            check "Set temperature block #{TEMP_BLOCK} to #{kit.fetch("elutionTemperature")} C"
            check "In a 1.5 mL tube, heat #{operations.running.length*kit.fetch("elutionVolume")*1.5} ÂµL of #{kit.fetch("elutionBuffer")} to #{kit.fetch("elutionTemperature")} C on temperature block #{TEMP_BLOCK}"
            note "The heated #{kit.fetch("elutionBuffer")} will be used in the final step of the purification"
        end

    end #def

    #---------------------------------------------------------------------
    # calculate volumes needed throughout protocol based on weight
    # CAREFUL! ioStr may refer to either parts (of stripwells), multiple gel slices, or non-part items
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def volumeSetup(ioStr, kitStr)

        # for testing - assign a random weight value
        if(debug)
            operations.each { |op| op.temporary[:weight] = (Random.rand(0.25) + 0.1).to_s }
        end

        # if already have weights defined, assign them to temporary for use further on
        ops_with_weight=operations.select { |op| !(op.input(ioStr).item.get(:weight).nil?) }.each { |opw| opw.temporary[:weight]=opw.input(ioStr).item.get(:weight) }

        # get weights of samples if not already defined
        # Stripwell
        stripwell_ops=operations.select { |op| op.temporary[:weight].nil? && op.input(ioStr).object_type.name=="Stripwell" }
        if(stripwell_ops.any?)
            show do
                title "Enter volume(s) of stripwell wells"
                note "Enter the volumes of the wells:"
                table stripwell_ops.start_table
                    .input_item(ioStr) # may be a collection id
                    .custom_column(heading: "well") { |op| op.input(ioStr).column + 1 } # well within collection
                    .get(:weight, type: 'number', heading: "Volume (ÂµL)", default: 50.0)
                    .end_table
            end
            stripwell_ops.each { |op|
                op.temporary[:weight] = "#{(op.temporary[:weight].to_f)/1000.0}"
            }
        end
        # Multiple Gel Slice
        multiple_ops=operations.select { |op| op.temporary[:weight].nil? && op.input(ioStr).object_type.name=="Multiple Gel Slices" }
        if(multiple_ops.any?)
            show do
                title "Weigh volume(s) of 'multiple gel' items"
                note "Weigh the tubes and and enter the maximum weight of the following samples:"
                table multiple_ops.start_table
                    .input_item(ioStr)
                    .custom_column(heading: "number of tubes") { |op| op.input(ioStr).item.get(:number_of_tubes) }
                    .get(:weight, type: 'number', heading: "MAXIMAL weight over ALL tubes (g)", default: 0.001)
                    .end_table
                note "Write the MAXIMAL weight for each 'multiple gel' item on tube labeled <b>1</b>"
            end
        end
        # non-collection, non-multiple items
        other_ops=operations.select { |op| op.temporary[:weight].nil? && !(op.input(ioStr).object_type.name=="Stripwell") && !(op.input(ioStr).object_type.name=="Multiple Gel Slices") }
        if(other_ops.any?)
            show do
                title "Weigh volume(s) of non-stripwell items"
                note "Weigh the tubes and and enter the volume of the following samples:"
                table other_ops.start_table
                    .input_item(ioStr) # may be a collection id
                    .get(:weight, type: 'number', heading: "Weight (g)", default: 0)
                    .end_table
                note "Write the tube weight on the side of each tube"
            end
        end

        # calculate volumes of buffers
        kit=findSettings(kitStr) # test for bad string
        if(kitStr=="Qiagen" || kitStr=='QiagenPink')
            operations.each do |op|
                op.temporary[:qg_volume]  = (op.temporary[:weight].to_f / DENSITY1).floor
                if add_isopropanol?(op, ioStr)
                    op.temporary[:iso_volume] =  (op.temporary[:weight].to_f / DENSITY2).floor
                else
                    op.temporary[:iso_volume] = 0
                end
                op.temporary[:total_volume] = op.temporary[:qg_volume] + op.temporary[:iso_volume]
            end
        elsif(kitStr=="Promega")
            operations.each do |op|
                op.temporary[:qg_volume]  = (1000*(op.temporary[:weight].to_f)).ceil
                op.temporary[:iso_volume] = 0 # isopropanol volume == 0 for Promega kit
                op.temporary[:total_volume] = op.temporary[:qg_volume]
            end
        end

        # these will need to be split
        operations.each do |op|
            op.temporary[:is_divided] = (op.temporary[:total_volume] >= 2000)
        end

    end # def

    def add_isopropanol?(op, ioStr)
        length = op.input(ioStr).sample.properties["Length"]
        return true unless length.is_a?(Numeric)
        length <= 500 || length >= 4000
    end

    #---------------------------------------------------------------------
    # add loading buffer
    # transfer gel slices to larger tubes if needed
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def addLoadingBuffer(ioStr, kitStr)

        kit=findSettings(kitStr)

        # gel items are non-stripwell
        show do
            title "Move gel slices to new tubes"
            note "Carefully transfer the gel slices in the following tubes each to a new 2.0 mL tube using a pipette tip:"
            table operations.select{|op| op.temporary[:total_volume].between?(1500, 2000)}.start_table
                .input_item(ioStr)
                .end_table
            note "Label the new tubes accordingly, and discard the old 1.5 mL tubes."
        end if operations.any? {|op| op.temporary[:total_volume].between?(1500, 2000)}

        # stripwell items
        show do
            title "Add the following volume of #{kit.fetch("loadingBuffer")} to the corresponding well:"
            table operations.start_table
                .input_item(ioStr)
                .custom_column(heading: "well") { |op| op.input(ioStr).column + 1 } # well within collection
                .custom_column(heading: "#{kit.fetch("loadingBuffer")} Volume (ÂµL)", checkable: true) { |op| op.temporary[:qg_volume]}
                .end_table
        end if operations.any? { |op| (op.input(ioStr).object_type.name=="Stripwell") }

        # multiple gel slice items
        show do
            title "Add the following volume of #{kit.fetch("loadingBuffer")} to each of the listed tubes:"
            table operations.start_table
                .input_item(ioStr)
                .custom_column(heading: "add to EACH of these tubes", checkable: true) { |op| "1-#{op.input(ioStr).item.get(:number_of_tubes)}"}
                .custom_column(heading: "#{kit.fetch("loadingBuffer")} Volume (ÂµL)", checkable: true) { |op| op.temporary[:qg_volume]}
                .end_table
        end if operations.any? { |op| (op.input(ioStr).object_type.name=="Multiple Gel Slices") }

        # non-stripwell, non-multiple gel slice items

        # non-stripwell items
        show do
            title "Add the following volume of #{kit.fetch("loadingBuffer")} to the corresponding tube:"
            table operations.start_table
                .input_item(ioStr)
                .custom_column(heading: "#{kit.fetch("loadingBuffer")} Volume (ÂµL)", checkable: true) { |op| op.temporary[:qg_volume]}
                .end_table
        end if operations.any? { |op| !(op.input(ioStr).object_type.name=="Stripwell") && !(op.input(ioStr).object_type.name=="Multiple Gel Slices") }

    end # def

    #---------------------------------------------------------------------
    # melt gel
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def meltGel(ioStr, kitStr)

        kit=findSettings(kitStr)

        show do
            title "Place all tubes in #{kit.fetch("meltTemperature")} C heat block"
            timer initial: { hours: 0, minutes: kit.fetch("meltTime") , seconds: 0}
            note "Vortex every few minutes to speed up the process"
            note "Retrieve after 5 minutes or when the gel slice is competely dissovled"
        end

        show do
            title "Equally distribute melted gel slices between tubes"
            note "Equally distribute the volume of the following tubes each between two 1.5 mL tubes:"
            table operations.select{ |op| op.temporary[:is_divided]}.start_table
                .input_item(ioStr)
                .end_table
            note "Label the new tubes accordingly, and discard the old 1.5 mL tubes"
        end if operations.any? { |op| op.temporary[:is_divided] }

        # isopropanol volume == 0 for Promega kit
        show do
            title "Add isopropanol"
            note "Add isopropanol according to the following table. Pipette up and down to mix."
            warning "Divide the isopropanol volume evenly between two 1.5 mL tubes #{operations.select{ |op| op.temporary[:is_divided]}.map{ |op| op.input("Gel").item.id}} since you divided one tube's volume into two earlier." if operations.any?{ |op| op.temporary[:is_divided]}
            table operations.select{ |op| op.temporary[:iso_volume] > 0 }.start_table
                .input_item(ioStr)
                .custom_column(heading: "Isopropanol (ÂµL)", checkable: true) { |op| op.temporary[:iso_volume]}
                .end_table
        end if operations.any? { |op| op.temporary[:iso_volume] > 0}

    end # def

    #---------------------------------------------------------------------
    # load sample on column
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def loadSample(ioStr,kitStr)

        kit=findSettings(kitStr)
    
        # load stripwell samples
        show do
            title "Load sample(s)"
            check "Grab <b>#{operations.length}</b> #{kit.fetch("column")}(s), label with 1 to #{operations.length} on the sides of the column and the collection tube."
            check "Be sure not to add more than #{MAX_VOL} ÂµL to each #{kit.fetch("column")}"
            warning "Vortex contents of 1.5 mL tube(s) thoroughly before adding to #{kit.fetch("column")}(s)!".upcase
            check "Add tube contents to LABELED #{kit.fetch("column")}(s) using the following table:"
            table operations.start_table
                .input_item(ioStr)
                .custom_column(heading: "well") { |op| op.input(ioStr).column + 1 } # well within collection
                .custom_column(heading: kit.fetch("column") ) { |op| operations.index(op) + 1 } # column index
                .end_table
            check "Wait for #{kit.fetch("loadingTime")} min before proceeding"
            timer initial: { hours: 0, minutes: kit.fetch("loadingTime"), seconds: 0}
        end if operations.any? { |op| (op.input(ioStr).object_type.name=="Stripwell") }

        # load non-stripwell samples
        show do
            title "Load sample(s)"
            check "Grab <b>#{operations.length}</b> #{kit.fetch("column")}(s), label with 1 to #{operations.length} on the sides of the column and the collection tube."
            check "Be sure not to add more than #{MAX_VOL} ÂµL to each #{kit.fetch("column")}"
            warning "Vortex contents of 1.5 mL tube(s) thoroughly before adding to #{kit.fetch("column")}(s)!".upcase
            check "Add tube contents to LABELED #{kit.fetch("column")}(s) using the following table:"
            table operations.start_table
                .input_item(ioStr)
                .custom_column(heading: kit.fetch("column") ) { |op| operations.index(op) + 1 } # column index
                .end_table
            check "Wait for #{kit.fetch("loadingTime")} min before proceeding"
            timer initial: { hours: 0, minutes: kit.fetch("loadingTime"), seconds: 0}
        end if operations.any? { |op| !(op.input(ioStr).object_type.name=="Stripwell") }

        show do
            title "Centrifuge sample(s)"
            check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to bind DNA to column(s)"
            check "Empty collection column(s) by pouring liquid waste into liquid waste container"
            warning "Add any remaining contents of the 1.5 mL tube(s) to their corresponding columns, and repeat the load and centrifugation steps for all tubes with remaining mixture!"
        end

    end # def

    #---------------------------------------------------------------------
    # load multiple gel slice sample on columns
    # ioStr - string, name of input item
    # kitStr - string, name of kit. "Qiagen", Promega"
    # note: ASSUME THAT THERE IS NO BATCHING!!!
    #---------------------------------------------------------------------
    def loadMultiGelSample(ioStr,kitStr)

        kit=findSettings(kitStr)

        operations.each { |op|

            num_columns=(op.input(ioStr).item.get(:number_of_tubes).to_f/2.0).ceil
            # build display table
            col1=Array (1..op.input(ioStr).item.get(:number_of_tubes).to_f)
            col2=col1.map {|v| (v/2.0).ceil }
            col1=col1.unshift("Input tube index")
            col2=col2.unshift("Output column index")
            tab = [col1, col2].transpose

            show do
                title "Load sample(s)"
                check "Grab <b>#{num_columns}</b> #{kit.fetch("column")}(s), label them 1 to #{num_columns}"
                note "You are loading the contents of two input tubes on each column, this may require <b>MULTIPLE ROUNDS</b> of loading"
                note "Be sure not to add more than #{MAX_VOL} ÂµL to each #{kit.fetch("column")}"
                check "Vortex tube(s), then transfer the contents of the tube(s) to the #{kit.fetch("column")}(s) using the following table:"
                table tab
                check "Wait <b>1 min</b>"
                check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to bind DNA to column(s)"
                check "Empty collection column(s) by pouring liquid waste into liquid waste container"
                warning "Add any remaining contents of the 1.5 mL tube(s) to their corresponding columns, and repeat the vortex, load, wait,  and centrifugation steps"
            end
        }
    end # def

    #---------------------------------------------------------------------
    # wash step
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def washSample(kitStr)

        kit=findSettings(kitStr)

        show do
          title "Wash sample(s)"

          if kitStr=="Qiagen" || kitStr=="QiagenPink"
            check "Add #{kit.fetch("secondRinseVol")} ÂµL #{kit.fetch("loadingBuffer")} to columns"
            check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to wash column(s)"
            check "Empty collection tube(s)"
          end

          check "Add #{kit.fetch("firstRinseVol")} ÂµL #{kit.fetch("washBuffer")} to columns"
          check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to wash column(s)"
          check "Empty collection tube(s)"

          check "Add #{kit.fetch("secondRinseVol")} ÂµL #{kit.fetch("washBuffer")} to columns"
          check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to wash column(s)"
          check "Empty collection tube(s)"

          check "Spin at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min to remove all buffer from column(s)"
        end
    end # def

       #---------------------------------------------------------------------
    # elution step - multiple gel slice version
    # ioStr1 - string, name of output item for 1st elution
    # ioStr2 - string, name of output item for 2nd elution
    # kitStr - string, name of kit. "Qiagen", Promega"
    #---------------------------------------------------------------------
    def eluteMultipleGelSample(inStr,outStr1,outStr2,kitStr)

        kit=findSettings(kitStr)

        operations.each { |op|

            num_columns=(op.input(inStr).item.get(:number_of_tubes).to_f/2.0).ceil

            # # build display table
            # col1=Array (1..op.input(inStr).item.get(:number_of_tubes).to_f)
            # col2=col1.map {|v| (v/2.0).ceil }
            # col1=col1.unshift("Input tube index")
            # col2=col2.unshift("Output column index")
            # tab = [col1, col2].transpose


            # incubation+elution- first round
            show do
                title "Elution - first round"
                check "Grab #{num_columns} sterile 1.5 mL tubes and label <b>ALL</b> of them <b>1</b>"
                check "Transfer the #{kit.fetch("column")} columns from the collection tubes to the 1.5 mL tubes labeled <b>1</b>"
                check "Add <b>#{kit.fetch("elutionVolume")} ÂµL</b> of <b>PREHEATED</b> molecular grade water to center of each column"
                warning "Be careful to not pipette on the wall of the tube"
                timer initial: {hours: 0, minutes: kit.fetch("elutionTime"), seconds: 0}
                check "Spin for #{kit.fetch("spinTime")} minute(s) at at #{kit.fetch("spinG")} xg to elute DNA"
                warning "Retain the columns for a second elution!"
            end

            # incubation+elution - second round
            show do
                title "Elution - second round"
                check "Grab #{num_columns} sterile 1.5 mL tubes and label <b>ALL</b> of them <b>2</b>"
                check "Transfer the columns from the tubes labeled <b>1</b> to the tubes labeled <b>2</b>"
                check "Add <b>#{kit.fetch("elutionVolume")} ÂµL</b> of <b>PREHEATED</b> molecular grade water to center of each column"
                warning "Be careful to not pipette on the wall of the tube"
                timer initial: {hours: 0, minutes: kit.fetch("elutionTime"), seconds: 0}
                check "Spin for #{kit.fetch("spinTime")} minute(s) at at #{kit.fetch("spinG")} xg to elute DNA"
                check "Remove and trash the columns"
            end

            # combine tubes with high, low cencentration samples
            show do
                title "Combine samples"
                check "Combine the contents of the tubes labeled <b>1</b> into one 1.5 mL tube (add one to the other) and label it <b>#{op.output(outStr1).item}</b>"
                check "Combine the contents of the tubes labeled <b>2</b> into one 1.5 mL tube (add one to the other) and label it <b>#{op.output(outStr2).item}</b>"
                check "Trash the empty used tubes"
            end

        } # each

    end # def

    #---------------------------------------------------------------------
    # elution step
    # ioStr - string, name of output item
    # kitStr - string, name of kit. "Qiagen", Promega"
    # doTwice - repeat elution using flowthrough if ==1, else only 1 elution round
    #---------------------------------------------------------------------
    def eluteSample(ioStr,kitStr,doTwice=1)

        kit=findSettings(kitStr)

        show do
            title "Elution"
            check "Apply the printed labels to clean 1.5 mL tubes"
            check "Transfer the #{kit.fetch("column")}s to the labeled 1.5 mL tubes using the following table:"
            table operations.start_table
                .custom_column(heading: kit.fetch("column")) { |op| operations.index(op) + 1 }
                .output_item(ioStr, heading: "1.5 mL tube", checkable: true)
            .end_table
            check "Add #{kit.fetch("elutionVolume")} ÂµL of <b>PREHEATED</b> #{kit.fetch("elutionBuffer")} to center of the column"
            warning "Be careful not to pipette on the wall of the tube"
            warning "Be careful not to touch the column with the tip"
            check "Set a timer for #{kit.fetch("elutionTime")} min. When it finishes, proceed to the next step."
            timer initial: { hours: 0, minutes: kit.fetch("elutionTime") , seconds: 0}
            if(doTwice==1)
                check "Elute DNA into 1.5 mL tubes by spinning at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min, <b>KEEP</b> the columns"
                check "Pipette the flow through (#{kit.fetch("elutionVolume")} ÂµL) onto the center of the column, spin again at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min"
            else
                check "Elute DNA into 1.5 mL tubes by spinning at #{kit.fetch("spinG")} xg for #{kit.fetch("spinTime")} min"
            end
            check "Discard the columns"
            check "Set temperature block #{TEMP_BLOCK} back to #{TEMP_BLOCK_T} C"
        end
    end # def

    #---------------------------------------------------------------------
    # measure concentration of samples, if not already measured
    # inputs: ioStr - string, name of output item to which the concentration is associated
    #         inOut - "input" or "output", indicates whether ioStr refers to an input or output item
    #         ops - which ops to measure
    #---------------------------------------------------------------------
    def measureConcentration(ioStr,inOut,ops=operations)

        case inOut

        when "input"

            show do
                title "Measure concentration"
                note "Go to B9 and vortex and nanodrop the following 1.5 mL tube(s), and enter the DNA concentration(s):"
                table ops.start_table
                    .input_item(ioStr)
                    .get(:conc, type: 'number', heading: "Concentration (ng/uL)", default: 7)
                    .get(:note, type: 'text', heading: "Notes")
                    .end_table
            end if ops.any? { |op| op.input_data(ioStr, :concentration).nil? }
            ops.each do |op|
                op.set_input_data(ioStr, :concentration, op.temporary[:conc])
                op.input(ioStr).item.notes =  op.temporary[:note]
            end if ops.any? { |op| op.input_data(ioStr, :concentration).nil? }

        when "output"

            show do
                title "Measure concentration"
                note "Go to B9 and vortex and nanodrop the following 1.5 mL tube(s), and enter the DNA concentration(s):"
                table ops.start_table
                    .output_item(ioStr)
                    .get(:conc, type: 'number', heading: "Concentration (ng/ÂµL)", default: 7)
                    .get(:note, type: 'text', heading: "Notes")
                    .end_table
            end if ops.any? { |op| op.output_data(ioStr, :concentration).nil? }
            ops.each do |op|
                op.set_output_data(ioStr, :concentration, op.temporary[:conc])
                op.output(ioStr).item.notes =  op.temporary[:note]
            end if ops.any? { |op| op.output_data(ioStr, :concentration).nil? }

        else
            show do
                title "Problem with inOut string #{inOut} in #{__method__.to_s}, exiting."
                return
            end
        end # case

    end # def

    #---------------------------------------------------------------------
    # save/discard samples based on concentration
    # inputs: ioStr - string, name of output item to which the concentration is associated
    #         ops - which operations to check
    # outputs:
    #---------------------------------------------------------------------
    def saveOrDiscard(ioStr,ops=operations)
        choices = {}

        choices = show do
            title "Decide whether to keep dilute stocks"
            note "The below stocks have a concentration of less than 10 ng/ÂµL"
            note "Talk to a lab manager to decide whether or not to discard the following stocks"
            ops.select{ |op| op.output_data(ioStr, :concentration) < 10}.each do |op|
                select ["Yes", "No"], var: "d#{op.output(ioStr).item.id}", label: "Discard Fragment Stock #{op.output(ioStr).item}", default: 0
            end
        end if ops.any?{ |op| op.output_data(ioStr, :concentration) < 10}

        show do
          title "Discard fragment stocks"
          note "Discard the following fragment stocks:"
          note ops.select{ |op| choices["d#{op.output(ioStr).item.id}".to_sym] == "Yes"}
            .map{ |op| op.output(ioStr).item}
            .join(", ")
        end if choices.any? { |key, val| val == "Yes"}

        ops.select { |op| choices["d#{op.output(ioStr).item.id}".to_sym] == "Yes" }.each do |op|
            frag = op.output(ioStr).item
            op.error :low_concentration, "The concentration of #{frag} was too low to continue"
            frag.mark_as_deleted
        end
    end # def

    #---------------------------------------------------------------------
    # sort items (including stripwell subitems) for table display
    # algorithm: increasing in ascending numberical order of table_val, where table_val is defined as:
    # stripwell_id.colum_id (floating point)
    # inputs: op - operation
    #         ioStr - string, name of input/output used for sorting
    #         inOut - "input" or "output"
    #---------------------------------------------------------------------
    def sortOperations(ioStr,inOut)
        operations.sort! { |a, b| tableVal(a, ioStr, inOut) <=> tableVal(b, ioStr, inOut) }
    end
    #---------------------------------------------------------------------
    # calculates value of item (including stripwell subitems) for sort
    # algorithm: increasing in ascending numberical order of table_val, where table_val is defined as:
    # stripwell_id.colum_id (floating point)
    # inputs: op - operation
    #         ioStr - string, name of input/output used for sorting
    #         inOut - "input" or "output"
    #---------------------------------------------------------------------
    def tableVal(op, ioStr, inOut)
        val=0
        case inOut
        when "input"
            val=op.input(ioStr).item.id.to_f + op.input(ioStr).column.to_f/100.0
        when "output"
            val=op.output(ioStr).item.id.to_f + op.output(ioStr).column.to_f/100.0
        end
        # return
        val
    end

end # module