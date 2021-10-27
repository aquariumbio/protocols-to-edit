module MidiprepMaxiprep
    def midimaxi_steps operations, type
        elution_volume = max_vol = tube_size = vol_p = vol_qc = stock_tube_size = vol_qf = syringe_size = vol_te = 0
        if type == :midiprep
            max_vol = 50 # volume of overnight to use
            tube_size = 50 # tube size for culture
            vol_qbt = 4 # volume of QBT buffer
            vol_p = 6 # volumes of P1, P2, and P3 to pipette
            vol_qc = 20 # volume of Buffer QC to pipette
            stock_tube_size = 15 # tube size for stock
            vol_qf = 5 # volume of QF to pipette
            vol_iso = 3.5 # volume of isopropanol to pipette
            syringe_size = 20 # syringe size for eluate-isopropanol mixture
            vol_te = "500 ÂµL" # volume of TE buffer to pipette
            elution_volume = 500 # volume after elution(?)
        else
            max_vol = 200 # volume of overnight to use
            tube_size = 225 # tube size for culture
            vol_qbt = 10 # volume of QBT buffer
            vol_p = 20 # volumes of P1, P2, and P3 to pipette
            vol_qc = 60 # volume of Buffer QC to pipette
            stock_tube_size = 50 # tube size for stock
            vol_qf = 15 # volume of QF to pipette
            vol_iso = 10.5 # volume of isopropanol to pipette
            syringe_size = 30 # syringe size for eluate-isopropanol mixture
            vol_te = "1 mL" # volume of TE buffer to pipette
            elution_volume = 1000 # volume after elution(?)
        end
        
        show do
          	title "Set centrifuge to 4 degrees C"
        end
    
        operations.retrieve
    
        verify_growth = show do
            title "Check if overnights have growth"
            note "Choose No for the overnight that does not have growth. Empty flask and put in the clean station."
            operations.each do |op|
                on = op.input("Overnight").item
                select ["Yes", "No"], var: "verify#{on.id}", label: "Does flask #{on.id} have growth?"
            end
        end
    
        operations.select { |op| verify_growth[:"verify#{op.input("Overnight").item.id}".to_sym] == "No" }.each do |op|
            on = op.input("Overnight").item
            on.mark_as_deleted
            on.save
            
            op.error :no_growth, "Your overnight had no growth!"
        end
        
        operations.make
     
        operations.each do |op|
            od_data = show do
                title "Grow #{op.input("Overnight").item.id} to an OD between 0.12 and 0.16"
        
                check "Make a 1:10 dilution in TB + Antibiotic (90 ÂµL media, 10 ÂµL cells)."
                check "Open nanodrop in cell cultures mode."
                check "Blank with TB + antibiotic"
                get "number", var: "od", label: "Record OD 600 of #{op.input("Overnight").item.id}", default: 0.12
            end
    
            op.temporary[:od] = od_data[:od]
        end
    
        operations.each do |op|
            vol_coef = max_vol * 0.14 # constant s.t. vol_coef / [optimal OD] = max_vol
            volume = [max_vol, (vol_coef / op.temporary[:od]).round(1)].min
            show do
                title "Transfer culture into centrifuge tubes"
            	check "Label 1 #{tube_size} mL falcon tube with overnight id #{op.input("Overnight").item.id}" 
            	check "Transfer #{volume} mL of overnight culture #{op.input("Overnight").item.id} into each labeled tube."
            end
        end
          
        operations.each do |op|  
            show do
                title "Spin down the cells labeled as #{op.input("Overnight").item.id}"
                check "Spin at 4,696 xg for 15 min at 4 C"
                check "Once you've started the centrifuge, click ok" 
            end
        end
      
      	show do
    		title "Place all empty flasks at the clean station"
    	end
        
        show do
    		title "Prepare equipment during spin"
    		check "During the spin, take out #{operations.length} QIAfilter Cartridge(s). Label them with #{operations.map { |op| op.input("Overnight").item.id }}. Screw the cap onto the outlet nozzle of the QIAfilter Cartridge(s). Place the QIAfilter Cartridge(s) into a convenient tube or test tube rack."
    		check "Label #{operations.length} HiSpeed Tip(s). Place the HiSpeed Tip(s) onto a tip holder, resting on a 250 mL beaker. Add #{vol_qbt} mL of QBT buffer to the HiSpeed Tip(s), allowing it to enter the resin."
       	 end
    
    	show do
    		title "Retrieve centrifuge tubes"
    	    check "Remove the supernatant from all the tubes. Pour off the supernatant into liquid waste, being sure not to upset the pellet. Pipette out the residual supernatant."
        end
        
        show do
            title "Resuspend cells in P1"
            check "Add #{vol_p} mL of P1 into each centrifuge tube using the serological pipet and vortex strongly to resuspend."
        end
        
        show do
            title "Add P2"
            check "Add #{vol_p} mL of P2 into each centrifuge tube using the serological pipette and gently invert 4-6 times to mix."
            check "Incubate tube at room temperature for 5 minutes."
    		  
            warning "Cells should not be exposed to active P2 for more than 5 minutes."
        end
        
    
        show do
            title "Add prechilled P3 and gently invert to mix"
    	    check "Pipette #{vol_p} mL of prechilled P3 into each tube with serological pipette and gently invert 4-6 times to mix."
        end
        
        show do
            title "Centrifuge tubes at 4,696 xg for 30 mins at 4 C "
            check "Once you've started the centrifuge, click ok"
        end
        
        operations.each do |op|  
            show do
            	title "Filter lysate #{op.input("Overnight").item.id} through QIAfilter Cartridge into HiSpeed tip"
        		check "Pour #{op.input("Overnight").item.id} lysate from the centrifuge tube into the capped QIAfilter Cartridge labeled #{op.input("Overnight").item.id}."
                check "Incubate in QIAfilter cartridge for 10 minutes."
        		check "Remove the plunger from a 30 mL syringe."
        		check " Take the cap off the QIAfilter Cartridge outlet nozzle. Gently insert the plunger 
        			into the QIAfilter Cartridge, and depress slowly so the cell lysate enters the HiSpeed Tip labeled #{op.input("Overnight").item.id} ."
        		check "Continue doing this until all the lysate has been transfered to the HiSpeed Tip"
        		check "Discard the QIAfilter Cartridge after all lysate has been removed."
        	end
        end
        
        stock_tube_name = type == :midiprep ? "15 mL Conical Tube(s)" : "50 mL falcon tube(s)"
    	show do
    		title "Wash HiSpeed tips with QC buffer"
    		check "After all the lysate has entered, add #{vol_qc} mL Buffer QC to each HiSpeed tip #{operations.map { |op| op.input("Overnight").item.id }}. Allow the wash to fiter through the tip by gravity flow."
    		check "While you are waiting for the buffer to filter through the tip, get #{operations.length} #{stock_tube_name}. Label them #{operations.map { |op| op.input("Overnight").item.id }} respectively and put them in a tube stand."
    		warning "Do not proceed to the next step until all wash liquid has filtered through the tip (it stops dripping)."
    	end
    
        operations.each do |op| 
        	show do
        		title "Elute DNA into #{stock_tube_size} mL tube"
        		check "Place the cap off the #{stock_tube_size} mL tube labeled #{op.input("Overnight").item.id}. Take the HiSpeed tip labeled #{op.input("Overnight").item.id} and tip stand and move them so they are over the #{stock_tube_size} mL tube."
        		check "Add #{vol_qf} mL Buffer QF to the HiSpeed tip to elute DNA into the #{stock_tube_size} mL tube."
        		warning "Do not elute DNA into the waste container, or DNA will be lost!"
    		end
    	end
    
    	show do
    		title "Discard HiSpeed tips"
    		check "Discard the HiSpeed tips after the buffer has finished dripping through."
    	end
    	
    	show do
    		title "Precipitate DNA in #{stock_tube_size} mL tube"
    		check "Precipitate DNA by adding #{vol_iso} mL isopropanol to the #{operations.length} #{stock_tube_name}. Put the lids back on the #{stock_tube_size} mL tubes and mix gently by inverting. Let stand for 5 min."
    		check "While waiting, click ok" 
    	end
    	
    	show do
    		title "Prepare equipment"
    		check "Label #{operations.length} QIAprecipitator modules(s) with #{operations.map { |op| op.input("Overnight").item.id }} respectively"
    		check "Remove the plunger from #{operations.length} new #{syringe_size} mL syringe and attach the labeled QIAprecipitator Module(s) to the outlet nozzle."
    	end
    
        show do
            title "Make fresh 70% ethanol"
        
            check "Measure out #{7 * operations.length} mL 100% ethanol (NOT 95%, in the flammables cabinet) using a serological pipette."
            check "Add #{3 * operations.length} mL MG water." 
        end
    	
        operations.each do |op| 
        	show do
        		title "Filter DNA through QIAprecipitator"
        		check "Place the QIAprecipitator labeled #{op.input("Overnight").item.id} over a waste bottle, transfer the eluate-isopropanol mixture from the #{op.input("Overnight").item.id} #{stock_tube_size} mL tube into the syringe, and insert the plunger. Depress the plunger and filter the mixture through the QIAprecipitator."
    		end
    	end
    
    	operations.each do |op|
        	show do
        		title "Wash DNA with 70 percent ethanol"
        		check "Remove the QIAprecipitator labeled #{op.input("Overnight").item.id} from the syringe and pull out the plunger. Re-attach the QIAprecipitator and add 2mL 70 percent ethanol to the syringe. Wash the DNA by the inserting the plunger and pressing the ethanol through the QIAprecipitator."
    		end
    	end
    
    	operations.each do |op|	
        	show do
        		title "Dry the QIAprecipitator membrane"
        		check "Remove the QIAprecipitator labeled #{op.input("Overnight").item.id} from the syringe and pull out the plunger carefully. Re-attach the QIAprecipitator, insert the plunger, and dry the membrane by pressing air through the QIAprecipitatior quickly. Repeat the whole step 3 times."
        		check "Dry the outlet nozzle of the QIAprecipitator with a paper towel. Discard the syringe and plunger"
    		end
    	end
        
        show do
            title "Prepare 1.5 mL tubes"
            note " Retrive #{operations.length} 1.5 mL tubes and add a white sticker to the top of each tube. Label them with the item ids in the following table"
            table operations.start_table
                .custom_column(heading: "Tube number") { |op| operations.index(op) + 1 }
                .output_item("Stock", heading: "Item id", checkable: true)
            .end_table
        end
    	
    	operations.each do |op|
    	    on = op.input("Overnight").item.id
    	    stock = op.output("Stock").item.id
                
    	    show do
        		title "Elute DNA into the 1.5 mL collection tubes"
        		warning "Type of elution buffer: #{op.input('Elution Buffer').val}" if op.input('Elution Buffer')
        		check "Remove the plunger from a new 5 mL syringe, attach the QIAprecipitator labeled #{on} and hold the outlet over the 1.5 mL collection tube labeled #{stock}." 
        		if op.input('Elution Buffer')
        		    check "Add #{vol_te} #{op.input('Elution Buffer').val} to the 5 mL syringe."
        		else
        		    check "Add #{vol_te} TE Buffer to the 5 mL syringe."
        		end
        		check "Insert the plunger and elute the DNA by depressing the plunger."
    		end
    	end
    
    	operations.each do |op|
    	    on = op.input("Overnight").item
    	    stock = op.output("Stock").item
    	    
    	    show do
        		title "Final filtering"
        		check "Remove the QIAprecipitator labeled #{on} from the 5 mL syringe, pull out the plunger and re-attach the QIAprecipitator to the 5 mL syringe." 
        		check "Transfer the eluate from the 1.5 mL tube labeled #{stock} into the 5 mL syringe and elute QIAprecipitator #{on} for a second time into the same 1.5 mL tube (labeled #{stock})."
    		end
    	end
        
        data = show do
            title "Nanodrop all labeled 1.5 mL tubes"
            operations.each do |op|
                stock = op.output("Stock").item
                get "number", var: "conc#{stock.id}", label: "Enter concentration of #{stock}", default: 1500 
            end
        end
    
        volume = elution_volume - 2
    
      	operations.each do |op|
      		op.output("Stock").item.associate(:concentration, data["conc#{op.output("Stock").item.id}".to_sym])
      		  .associate(:volume, volume)
      		  .associate(:from, op.input("Overnight").item.id)
      		op.input("Overnight").item.mark_as_deleted
      	end
        
        operations.store
    end
end