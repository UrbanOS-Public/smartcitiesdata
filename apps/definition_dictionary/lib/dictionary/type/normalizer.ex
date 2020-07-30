defprotocol Dictionary.Type.Normalizer do
  @spec normalize(dictionary :: t, value :: term) :: {:ok, term} | {:error, term}
  def normalize(t, value)
end
