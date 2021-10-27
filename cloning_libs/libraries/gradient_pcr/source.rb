module GradientPCR
  def distribute_pcrs operations, num_therm
    frags_by_bins = sort_fragments_into_bins operations, num_therm
    frags_by_bins.reject { |frag_hash| frag_hash[:rows].empty? }.map do |frag_hash|
      { 
        ops_by_bin: Hash[frag_hash[:rows].sort], bins: frag_hash[:bins], mm: 0, ss: 0, fragments: [], templates: [], forward_primers: [],
        reverse_primers: [], forward_primer_ids: [], reverse_primer_ids: [], stripwells: [], tanneals: [] 
      }
    end
  end

  def sort_fragments_into_bins operations, num_therm
    operations.each do |op|
        t1 = op.input("Forward Primer").sample.properties["T Anneal"]
        t2 = op.input("Reverse Primer").sample.properties["T Anneal"]
        op.temporary[:tanneal] = [t1, t2].min
    end
    
    temps_by_bins = sort_temperatures_into_bins operations.map { |op| op.temporary[:tanneal] }, num_therm

    operations_copy = Array.new(operations)
    temps_by_bins.map do |grad_hash|
      frag_hash = { bins: grad_hash[:bins], rows: Hash.new { |h, k| h[k] = [] } }
      grad_hash[:rows].each do |b, ts|
        frag_hash[:rows][b] += ts.map do |t|
          op = operations_copy.find { |op| op.temporary[:tanneal] == t }
          operations_copy.delete_at(operations_copy.index(op))
          op
        end
      end
      
      frag_hash[:rows].each { |b, ops| ops.extend(OperationList) }
      frag_hash
    end
  end

  def sort_temperatures_into_bins an_temps, num_therm
    bins = [0.0, 0.75, 2.0, 3.7, 6.1, 7.9, 9.3, 10.0]
    puts "\n#{"Annealing temperatures:"} #{an_temps.to_s}"

    best_bin_set = find_best_bin_set an_temps, bins, (40..72).map { |t| t / 1 }, Array.new, num_therm
    best_grad_set = make_grad_hash_set_from_bin_set(an_temps, best_bin_set)
    puts "\n#{"Best bin set:"} #{best_bin_set}"
    puts "\n#{"Best gradient set score:"} #{score_set best_grad_set}"
    puts "#{"Best gradient set: "} #{therm_format best_grad_set}"

    opt_best_grad_set = optimize_grad_set best_grad_set
    puts "\n#{"Best gradient set (optimized) score:"} #{score_set opt_best_grad_set}"
    puts "#{"Best gradient set (optimized): "} #{therm_format opt_best_grad_set}"
    puts opt_best_grad_set

    normal_bin_set = [[44],[60],[64],[67]]
    normal_grad_set = make_grad_hash_set_from_bin_set an_temps, normal_bin_set
    puts "\n#{"Normal gradient set score:"} #{score_bin_set an_temps, normal_bin_set}"
    puts "#{"Normal gradient set:"} #{therm_format normal_grad_set}"

    return opt_best_grad_set
  end

  def find_best_bin_set temps, bins, transforms, base_bin_set, num_bin_sets
    return base_bin_set if num_bin_sets == 0

    best_bin_set = nil
    transforms.each { |trans|
      t_bins = bins.map { |t| t + trans }
      next_base_bin_set = [t_bins] + base_bin_set
      next if (make_grad_hash temps, next_base_bin_set.flatten).nil?

      bin_set = (find_best_bin_set temps, bins, transforms[1..-1], next_base_bin_set, num_bin_sets - 1)
      best_bin_set ||= bin_set
      best_bin_set = bin_set if score_bin_set(temps, bin_set) < score_bin_set(temps, best_bin_set)
    }
    best_bin_set
  end

  def make_grad_hash temps, bins
    bin_rev = bins.reverse
    grad_hash = { bins: bins, rows: Hash.new { |h, k| h[k] = [] } }
    temps.each { |t|
      key = "#{bin_rev.find { |b| b <= t }}"
      return nil if key.empty?
      grad_hash[:rows][key].push t
    }
    grad_hash
  end

  def score grad_hash
    score = 0.0
    grad_hash[:rows].each { |b, ts|
      ts.each { |t| score = score + t - b.to_f }
    }
    score
  end

  def score_temps temps, bin
    temps.inject(0) { |sum, t| sum + t - bin }
  end

  def score_set grad_hash_set
    total = 0.0
    grad_hash_set.each { |grad_hash| total = total + score(grad_hash) }
    total.round(2)
  end

  def score_bin_set temps, bin_set
    grad_hash = make_grad_hash temps, bin_set.flatten.sort
    score(grad_hash).round(2)
  end

  def make_grad_hash_set_from_bin_set temps, bin_set
    grand_grad_hash = make_grad_hash temps, bin_set.flatten.sort
    bin_set.map { |bins|
      row_hash = Hash.new
      bins.each do |b|
        if grand_grad_hash[:rows][b.to_s].any?
          row_hash[b.to_s] = grand_grad_hash[:rows][b.to_s]
          grand_grad_hash[:rows].delete(b.to_s)
        end
      end
      { bins: bins, rows: row_hash }
    }
  end

  def optimize_grad_set grad_set
    grad_set.each_with_index do |grad_hash, idx|
      if grad_hash[:rows].length <= 1 # Can take another temperature set
        high_score_hash_and_bin = find_highest_scoring_hash_and_bin grad_set, grad_hash
        if !high_score_hash_and_bin[:hash].empty? # Move highest scoring temperature set to this grad_hash
          hs_bin = high_score_hash_and_bin[:bin]
          hs_ts = high_score_hash_and_bin[:hash][hs_bin]
          grad_hash[:rows].merge!({ hs_bin => hs_ts }) { |bin, ts1, ts2| ts1 + ts2 }
          high_score_hash_and_bin[:hash].delete(hs_bin)
        end
        if grad_hash[:rows].length == 1 && grad_set[(idx + 1)..-1].any? { |gh| gh[:rows].length == 1 } # Move isolated temperature set to this grad_hash
          targ_hash = grad_set[(idx + 1)..-1].find { |gh| gh[:rows].length == 1 }
          targ_bin = targ_hash[:rows].keys.find { |b| targ_hash[:rows][b].any? }
          grad_hash[:rows].merge!({ targ_bin => targ_hash[:rows][targ_bin] }) { |bin, ts1, ts2| ts1 + ts2 }
          targ_hash[:rows].delete(targ_bin)
          #puts "HEY"
        end
      end

      update_rows grad_hash
    end
    
    grad_set.each { |grad_hash| update_rows grad_hash }
  end

  def update_rows grad_hash  
    if grad_hash[:rows].length == 1 # Set single temperature
      row = grad_hash[:rows].values.first
      grad_hash[:rows] = { row.min.to_s => row.sort }
      grad_hash[:bins] = [row.min]
    elsif grad_hash[:rows].length == 2 # Set the upper and lower temperature bounds
      rows = grad_hash[:rows].values
      grad_hash[:rows] = { rows.first.min.to_s => rows.first.sort, rows.last.min.to_s => rows.last.sort }
      grad_hash[:bins] = [grad_hash[:rows].keys.min.to_f, grad_hash[:rows].keys.max.to_f].sort
    end
  end

  def num_bins_with_any_temps_set grad_set
    grad_set.map { |gh| gh[:rows].values.inject(0) { |sum, ts| sum + (ts.any? ? 1 : 0) } }
  end

  def find_highest_scoring_hash_and_bin grad_set, grad_hash
    high_score_hash_and_bin = nil
    grad_set.each { |gh|
      next if gh == grad_hash || gh[:rows].length <= 2
      gh[:rows].each { |b, ts|
        high_score_hash_and_bin ||= { hash: gh[:rows], bin: b }
        hs_bin = high_score_hash_and_bin[:bin]
        hs_ts = high_score_hash_and_bin[:hash][hs_bin]
        if score_temps(ts, b.to_f) > score_temps(hs_ts, hs_bin.to_f)
          high_score_hash_and_bin = { hash: gh[:rows], bin: b }
        end
      }
    }
    high_score_hash_and_bin || { hash: {}, bin: "" }
  end

  def therm_format grad_set
    str = ""
    grad_set.each_with_index { |grad_hash, idx|
      str += "\n#{"Therm #{idx + 1}:"} Set gradient #{grad_hash[:bins].first}-#{grad_hash[:bins].last}"
      grad_hash[:rows].each { |b, ts|
        str += "\n    #{b}: #{ts.to_s}"
      }
    }
    str
  end
end