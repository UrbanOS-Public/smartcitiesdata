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
      "string" => "String",
      "map" => "Map",
      "boolean" => "Boolean",
      "date" => "Date",
      "timestamp" => "Timestamp",
      "integer" => "Integer",
      "float" => "Float",
      "list" => "List"
    }
  end

  def pii() do
    %{
      "none" => "None",
      "direct" => "Direct",
      "indirect" => "Indirect"
    }
  end

  def demographic_traits() do
    %{
      "none" => "None",
      "gender" => "Gender",
      "race" => "Race",
      "age" => "Age",
      "income" => "Income",
      "other" => "Other"
    }
  end

  def biased() do
    %{
      "no" => "No",
      "yes" => "Yes"
    }
  end

  def masked() do
    %{
      "n/a" => "N/A",
      "yes" => "Yes",
      "no" => "No"
    }
  end
end
