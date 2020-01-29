defmodule DiscoveryApi.Schemas.Generators do
  @moduledoc false

  @size 8
  @alphabet "abcdefghijklmnopqrstuvwxyz0123456789"

  def generate_public_id(size \\ @size, alphabet \\ @alphabet) do
    Nanoid.generate(size, alphabet)
  end
end
