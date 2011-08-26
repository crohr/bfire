class Numeric

  def K;    self*10**3;     end
  def M;    self*10**6;     end
  def G;    self*10**9;     end
  def T;    self*10**12;    end

  {
    :KiB => 1024, :MiB => 1024**2, :GiB => 1024**3, :TiB => 1024**4,
    :KB => 1.K/1.024, :MB => 1.M/1.024**2, :GB => 1.G/1.024**3, :TB => 1.T/1.024**4
  }.each do |method, multiplier|
    define_method(method) do
      self*multiplier
    end
  end
end