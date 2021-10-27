eval Library.find_by_name("Preconditions").code("source").content
extend Preconditions

def precondition(op) 
    if op.input("Plasmid").object_type.name == "Ligation Product" 
        return time_elapsed op, "Plasmid", hours: 2
    else
        return true
    end
    
    if op.input("Plasmid").sample.properties["Bacterial Marker"].nil? || op.input("Plasmid").sample.properties["Bacterial Marker"] == ""
        return false
    end
end