defprotocol Decoder do
  @spec lines_or_bytes(t) :: :line | pos_integer()
  def lines_or_bytes(t)

  @spec decode(t, Enum.t()) :: Enum.t()
  def decode(t, messages)
end
