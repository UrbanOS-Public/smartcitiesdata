defmodule Pipeline.Writer.S3Writer.S3SafeJsonTest do
  use ExUnit.Case
  use Placebo

  alias Pipeline.Writer.S3Writer.S3SafeJson

  describe "build/2" do
    test "correctly maps integer and string fields" do
      data = %{
        "a_date" => "2020-02-11T00:00:00Z",
        "a_integer" => 66_251,
        "a_list" => ["2020-02-11T00:00:00Z", "2020-02-11T00:00:00Z"],
        "a_list_of_maps" => [
          %{"a_deep_date" => "2020-02-11T00:00:00Z"},
          %{"a_deep_date" => "2020-02-11T00:00:00Z"}
        ],
        "a_map" => %{"a_deep_date" => "2020-02-11T00:00:00Z"},
        "a_string" => "Salvatore MacGyver"
      }

      expected_data = %{
        "a_date" => "2020-02-11",
        "a_integer" => 66_251,
        "a_list" => ["2020-02-11", "2020-02-11"],
        "a_list_of_maps" => [
          %{"a_deep_date" => "2020-02-11"},
          %{"a_deep_date" => "2020-02-11"}
        ],
        "a_map" => %{"a_deep_date" => "2020-02-11"},
        "a_string" => "Salvatore MacGyver"
      }

      schema = [
        %{name: "a_integer", type: "integer"},
        %{name: "a_string", type: "string"},
        %{name: "a_date", type: "date"},
        %{name: "a_list", type: "list", itemType: "date"},
        %{name: "a_map", type: "map", subSchema: [%{name: "a_deep_date", type: "date"}]},
        %{name: "a_list_of_maps", type: "list", itemType: "map", subSchema: [%{name: "a_deep_date", type: "date"}]}
      ]

      result = S3SafeJson.build(data, schema)

      assert result == expected_data
    end

    test "handles a variety of different date and timestamp formats" do
      data = %{
        "a_timestamp_with_utc_zone" => "2020-02-11T16:16:14.999572Z",
        "a_timestamp_without_zone" => "2020-02-11T16:16:14.999572",
        "a_timestamp_with_non_fractional_with_zone" => "2020-02-11T16:16:14Z",
        "a_timestamp_with_non_fractional_without_zone" => "2020-02-11T16:16:14"
      }

      expected_data = %{
        "a_timestamp_with_utc_zone" => "2020-02-11 16:16:14",
        "a_timestamp_without_zone" => "2020-02-11 16:16:14",
        "a_timestamp_with_non_fractional_with_zone" => "2020-02-11 16:16:14",
        "a_timestamp_with_non_fractional_without_zone" => "2020-02-11 16:16:14"
      }

      schema = [
        %{name: "a_timestamp_with_utc_zone", type: "timestamp"},
        %{name: "a_timestamp_without_zone", type: "timestamp"},
        %{name: "a_timestamp_with_non_fractional_with_zone", type: "timestamp"},
        %{name: "a_timestamp_with_non_fractional_without_zone", type: "timestamp"}
      ]

      result = S3SafeJson.build(data, schema)

      assert result == expected_data
    end

    test "handles empty/missing dates and timestamps" do
      data = %{
        "a_timestamp_that_is_empty" => "",
        "a_date_that_is_empty" => ""
      }

      expected_data = %{
        "a_timestamp_that_is_missing_in_record" => nil,
        "a_timestamp_that_is_empty" => nil,
        "a_date_that_is_empty" => nil,
        "a_date_that_is_missing_in_record" => nil
      }

      schema = [
        %{name: "a_timestamp_that_is_missing_in_record", type: "timestamp"},
        %{name: "a_timestamp_that_is_empty", type: "timestamp"},
        %{name: "a_date_that_is_empty", type: "date"},
        %{name: "a_date_that_is_missing_in_record", type: "date"}
      ]

      result = S3SafeJson.build(data, schema)

      assert result == expected_data
    end

    test "handles stringified integers and floats" do
      data = %{
        "a_plus_signed_int" => "+1",
        "a_minus_signed_int" => "-1",
        "a_plus_signed_float" => "+1.0",
        "a_minus_signed_float" => "-1.0"
      }

      expected_data = %{
        "a_plus_signed_int" => 1,
        "a_minus_signed_int" => -1,
        "a_plus_signed_float" => 1.0,
        "a_minus_signed_float" => -1.0
      }

      schema = [
        %{name: "a_plus_signed_int", type: "integer"},
        %{name: "a_minus_signed_int", type: "integer"},
        %{name: "a_plus_signed_float", type: "float"},
        %{name: "a_minus_signed_float", type: "float"}
      ]

      result = S3SafeJson.build(data, schema)

      assert result == expected_data
    end

    test "handles converting from json hyphen data into sql safe safe underscored data" do
      data = %{
        "some-hyphen" => "aValue",
        "nested-hyphen" => %{"inner-hyphen" => 1, "other-inner_hyphen" => 2}
      }

      expected_data = %{
        "some_hyphen" => "aValue",
        "nested_hyphen" => %{"inner_hyphen" => 1, "other_inner_hyphen" => 2}
      }

      schema = [
        %{name: "some-hyphen", type: "string"},
        %{name: "nested-hyphen", type: "map", subSchema: [
            %{name: "inner-hyphen", type: "integer"},
            %{name: "other-inner_hyphen", type: "integer"},
          ]},
      ]

      result = S3SafeJson.build(data, schema)

      assert result == expected_data
    end
  end
end
