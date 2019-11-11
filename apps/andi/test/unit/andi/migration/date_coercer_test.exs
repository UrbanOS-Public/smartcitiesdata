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
      ["9/14/09", "2009-09-14T00:00:00Z"],
      ["1/01/2001", "2001-01-01T00:00:00Z"],
      ["9-14-15", "2015-09-14T00:00:00Z"],
      ["01-01-2002", "2002-01-01T00:00:00Z"],
      ["July 4, 2003", "2003-07-04T00:00:00Z"],
      ["2004-02-02", "2004-02-02T00:00:00Z"],
      ["Jan 4, 2005", "2005-01-04T00:00:00Z"],

    ])
  end
end
