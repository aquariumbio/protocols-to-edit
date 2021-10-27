# This module is used for general DNA/RNA/protein calculations

module Calculations
    # REFS:
    # https://www.thermofisher.com/us/en/home/references/ambion-tech-support/rna-tools-and-calculators/dna-and-rna-molecular-weights-and-conversions.html
    # https://nebiocalculator.neb.com/#!/formulas
    
    
    AVG_MW_BP = 617.96 # average molecular weight of a base pair g/mol
    AVAGADROS_NUM = 6.022 * 10**-23 # mol^-1
    
    # moles dsDNA = mass of dsDNA (g)/molecular weight of dsDNA (g/mol)
    # molecular weight of dsDNA = (number of base pairs of dsDNA x average molecular weight of a base pair) + 36.04 g/mol
    # average molecular weight of a base pair = 617.96 g/mol, excluding the water molecule removed during polymerization.
    # The 36.04 g/mol accounts for the 2 -OH and 2 -H added back to the end
    def dsDNA_molecular_weight(length)
        length * AVG_MW_BP + 36.04
    end
    
    def dsDNA_mass_to_moles(mass, length)
        mass / dsDNA_molecular_weight(length)
    end
    
    def dsDNA_moles_to_mass(moles, length)
        moles * dsDNA_molecular_weight(length)
    end
    
    def dsDNA_nguL_to_moles(nguL, uL, length)
        ng = nguL * uL 
        moles = dsDNA_mass_to_moles(ng * 10**-9, length)
        return moles
    end
    
end