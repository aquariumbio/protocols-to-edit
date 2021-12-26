class Protocol

    INPUT = 'Fragment Stock'

    def main
        # Locate required items and display instructions to get them.
        operations.retrieve
        verify_concentration(operations)
        # Put everything away.
        operations.store
    end

    # Verifies the concentration for operations.
    #
    # @param operations [Array] the operations to be executed
    def verify_concentration(operations)
        # Only one operation.
        op = operations[0]
        # Declare references to input object.
        input_stock = op.input(INPUT).item
        input_id = input_stock.id
        concentration = input_stock.get(:concentration)

        # Ask to verify concentration.
        resp = show do
            title "Verify concentration of fragment stock #{input_id}."
            select ["Yes", "No"], var: "correct_concentration", label: "Is the concentration of #{input_id} #{concentration} ng/ÂµL?", default: 0
        end

        if (resp.get_response(:correct_concentration) == "Yes")
            show do
                title 'Correct Concentration'
                note 'Concentration is correct, thanks for verifying!'
            end
        else
            show do
                title 'Incorrect Concentration'
                note 'What is the actual concentration?'
                table operations.start_table
                    .input_item(INPUT)
                    .get(:concentration, type: 'number', heading: "Fragment Stock Concentration (ng/ÂµL)", default: 0)
                    .end_table
            end

            show do
                new_concentration = op.temporary[:concentration].to_f
                input_stock.associate :concentration, new_concentration
                if (input_stock.get(:concentration) == new_concentration)
                    title 'Concentration Updated'
                    note "Concentration of #{input_id} updated to #{new_concentration} ng/ÂµL!"
                else
                    # This should never happen, but is handled just in case.
                    title 'Concentration Update Failed'
                    note "Concentration not updated. Please try again later!"
                end
            end
        end
    end
end