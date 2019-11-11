defmodule Andi.Migration.DateCoercerTest do
  use ExUnit.Case

  import Checkov

  alias Andi.Migration.DateCoercer

  data_test "coerces date #{input} into #{expected}" do
    assert expected == DateCoercer.coerce_date(input)

    where([
      [:input, :expected],
      ["", ""],
      ["2019-01-01T12:12:12Z", "2019-01-01T12:12:12Z"],
      ["09/14/09", "2009-09-14T00:00:00Z"]
    ])
  end
end
