defmodule Andi.InputSchemas.Options do

  def ratings() do
    %{
      0.0 => "Low",
      0.5 => "Medium",
      1.0 => "High"
    }
  end

  #TODO: add languages and other options in here
end
