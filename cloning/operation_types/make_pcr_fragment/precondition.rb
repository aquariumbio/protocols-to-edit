def validate_property sample, field_name
  validation_block = Proc.new
  property = sample.properties[field_name]
  if property.nil?
    raise "Could not find property #{field_name}"
  end
  validation_block.call(sample, property)
end

# Appends associates msgs to plan and operation
def precondition_warnings op, msgs, key=:precondition_warnings, sep=";"
  plan = op.plan
  if plan
    plan_msg = op.plan.get key
    plan_msgs = plan_msg.split(sep).map { |x| x.strip } if plan_msg
  end
  plan_msgs ||= []
  op_msgs = []

  msgs.each { |valid, m|
    if valid
      plan_msgs.delete(m)
    else
      plan_msgs << m
      op_msgs << m
    end
  }
  op_msgs.uniq!
  plan_msgs.uniq!

  op.associate key, op_msgs.join(sep + " ")
  op.plan.associate key, plan_msgs.join(sep + " ") if op.plan
end

def precondition(op)
  ready = true
  msgs = []
  
  #output fragment must have length!
  if op.output("Fragment").sample.properties["Length"].nil? || op.output("Fragment").sample.properties["Length"] <= 0
      op.associate("Output Fragment must have a defined length!", "")
      return false
  end

  # Validate sample, valid_block, valid_message
  ["Forward Primer", "Reverse Primer"].each do |n|
    sample = op.input(n).sample

    msgs << validate_property(sample, "T Anneal") { |s, property|
      validator = Proc.new { |p| p.to_f.between?(0.01, 100) }
      msg = "T Anneal #{property} for Primer \"#{s.name}\" is invalid"
      [validator.call(property), msg]
    }
  end
  msgs.select! { |valid, m| !valid }
  msgs.compact!
  precondition_warnings op, msgs
  ready = false if msgs.any?
  ready
end