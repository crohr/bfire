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

    def initialize(name, results)
      @name = name
      @results = results
    end
    
    def values
      @results.map{|r| r['value']}.reverse
    end
  end
end