defmodule Andi.InputSchemas.Options do
  @moduledoc false

  def ratings() do
    %{
      0.0 => "Low",
      0.5 => "Medium",
      1.0 => "High"
    }
  end

  def language() do
    %{
      "english" => "English",
      "spanish" => "Spanish"
    }
  end

  def level_of_access() do
    %{
      "true" => "Private",
      "false" => "Public"
    }
  end

  def items() do
    %{
      "string" => "string",
      "map" => "map",
      "boolean" => "boolean",
      "date" => "date",
      "timestamp" => "timestamp",
      "integer" => "integer",
      "float" => "float",
      "list" => "list"
    }
  end

  def pii() do
    %{
      "None" => "None"
    }
  end

  def demographic_traits() do
    %{
      "None" => "None"
    }
  end

  def biased() do
    %{
      "No" => "No"
    }
  end

  def masked() do
    %{
      "N/A" => "N/A"
    }
  end
end
