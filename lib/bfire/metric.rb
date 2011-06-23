class Array
  def sum
    inject(:+)
  end
  
  def avg
    sum.to_f / size
  end
  
  def median
    sorted = sort
    (sorted[size/2] + sorted[(size+1)/2]) / 2
  end
end

module Bfire
  class Metric

    def initialize(name, results, opts = {})
      @name = name
      @results = results
      @opts = opts
    end

    def values
      @results.map{|r| 
        case @opts[:type]
        when :numeric
          r['value'].to_f
        else
          r['value']
        end
      }.reverse
    end
  end
end