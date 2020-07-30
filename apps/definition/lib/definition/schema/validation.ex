defmodule Definition.Schema.Validation do
  @moduledoc """
  Defines custom functions for easily validating
  requirements for commonly encountered data types
  evaluate to a boolean.
  """

  @doc """
  Evaluates whether or not the supplied value is a
  valid ISO8601-formatted timestamp.

  # Examples

    iex> Definition.Schema.Validation.ts?("2020-18-10, 16:00 EST")
    false

    iex> DateTime.utc_now |> to_string |> Definition.Schema.Validation.ts?
    true
  """
  @spec ts?(input :: String.t()) :: boolean
  def ts?(input) when is_binary(input) do
    case DateTime.from_iso8601(input) do
      {:ok, _, _} -> true
      _ -> false
    end
  end

  def ts?(_), do: false

  @doc """
  Evaluates whether or not a supplied 2-element list
  of binary values represents a range of timestamps
  in ISO8601 format.

  # Examples

    iex> Definition.Schema.Validation.temporal_range?(["2010-12-10", "present"])
    false

    iex> Definition.Schema.Validation.temporal_range?(["2010-12-10T00:00:00Z", "2019-10-05 12:15:00Z"])
    true
  """
  @spec temporal_range?([String.t()]) :: boolean
  def temporal_range?([start, stop]) when is_binary(start) and is_binary(stop) do
    with {:ok, start_ts, _} <- DateTime.from_iso8601(start),
         {:ok, stop_ts, _} <- DateTime.from_iso8601(stop) do
      case DateTime.compare(start_ts, stop_ts) do
        :lt -> true
        :eq -> true
        :gt -> false
      end
    else
      _ -> false
    end
  end

  def temporal_range?(_), do: false

  @doc """
  Evaluates whether or not a supplied list of floating
  point numeric values represents a geospatial bounding
  box of coordinates.

  # Examples

    iex> Definition.Schema.Validation.bbox?("123.2, 156.0, 47.9, 84.23")
    false

    iex> Definition.Schema.Validation.bbox?([13.21, 24.21, 67.1, 93.256])
    true
  """
  @spec bbox?(bbox :: [float]) :: boolean
  def bbox?([x1, y1, x2, y2] = bbox) when x1 <= x2 and y1 <= y2 do
    Enum.all?(bbox, &is_float/1)
  end

  def bbox?(_), do: false

  @doc """
  Evaluates whether or not a supplied binary value represents
  a valid email address.

  # Example

    iex> Definition.Schema.Validation.email?("johnson.denen@gfy.today")
    true
  """
  @spec email?(input :: String.t()) :: boolean
  def email?(input) when is_binary(input) do
    Regex.match?(~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/, input)
  end

  def email?(_), do: false

  @doc """
  Evaluates whether or not a supplied value is considered
  "empty" according to that types term representation.

  # Examples

    iex> Definition.Schema.Validation.empty?("    ")
    true

    iex> Definition.Schema.Validation.empty?(%{})
    true

    iex> Definition.Schema.Validation.empty?([0])
    false
  """
  @spec empty?(input :: String.t() | list | map) :: boolean
  def empty?(""), do: true
  def empty?([]), do: true
  def empty?(input) when input == %{}, do: true

  def empty?(input) when is_binary(input) do
    case String.trim(input) do
      "" -> true
      _ -> false
    end
  end

  def empty?(_), do: false

  @doc """
  Evaluates the inverse of `empty?/1`; quickly check to
  ensure a value is not empty without negative predicates
  (not, !)
  """
  @spec not_empty?(input :: String.t() | list | map) :: boolean
  def not_empty?(input), do: not empty?(input)

  @doc """
  Evaluates whether or not a supplied value is considered
  to be `nil`.
  """
  @spec not_nil?(term) :: boolean
  def not_nil?(nil), do: false
  def not_nil?(_), do: true

  @doc """
  Evaluates whether input matches an acceptable table name pattern.
  """
  @spec table_name?(term) :: boolean
  def table_name?(input) when is_binary(input) do
    case String.split(input, "__", trim: true) do
      [_, _] -> true
      _ -> false
    end
  end

  def table_name?(_), do: false

  @doc """
  Evaluates whether input is a positive integer.
  """
  @spec pos_integer?(term) :: boolean
  def pos_integer?(input) when is_integer(input) and input > 0, do: true
  def pos_integer?(_), do: false

  @doc """
  Evaluates whether input is a valid port number.
  """
  @spec is_port?(term) :: boolean
  def is_port?(input) when is_integer(input) and 0 <= input and input <= 65_535, do: true
  def is_port?(_), do: false
end
