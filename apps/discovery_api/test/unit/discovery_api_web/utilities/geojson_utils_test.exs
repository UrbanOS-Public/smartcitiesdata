defmodule DiscoveryApiWeb.Utilities.GeojsonUtilsTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  require Logger
  alias DiscoveryApiWeb.Utilities.GeojsonUtils

  describe("calculate_bounding_box/1") do
    data_test "calculates bounding box for #{geometry_type}" do
      Logger.debug(fn -> "Testing #{geometry_type}" end)

      features = [
        %{"geometry" => %{"coordinates" => coordinates}}
      ]

      bounding_box = GeojsonUtils.calculate_bounding_box(features)

      assert bounding_box == expected_bounding_box

      where([
        [:geometry_type, :coordinates, :expected_bounding_box],
        ["point", [[1, 0]], [1, 0, 1, 0]],
        ["line", [[1, 0], [2, 0], [2, 1]], [1, 0, 2, 1]],
        [
          "polygon",
          [[[1, 1], [1, 0], [0, 1], [1, 1]], [[3, 3], [3, 2], [2, 3], [3, 3]]],
          [0, 0, 3, 3]
        ],
        [
          "multiline string",
          [
            [[10, 10], [20, 20], [10, 40]],
            [[40, 40], [30, 30], [40, 20], [30, 10]]
          ],
          [10, 10, 40, 40]
        ],
        ["empty coordinates", [], nil]
      ])
    end

    test "the bounding box of a list of polygons is calculated" do
      features = [
        %{
          "geometry" => %{
            "coordinates" => [[[-1, 8], [4, 8], [4, 13], [-1, 13], [-1, 8]]]
          }
        },
        %{
          "geometry" => %{
            "coordinates" => [[[-7, 12], [-12, 11], [-9, 8], [-3, 10], [-7, 12]]]
          }
        }
      ]

      bounding_box = GeojsonUtils.calculate_bounding_box(features)

      assert bounding_box == [-12, 8, 4, 13]
    end

    test "the bounding box of a list of features where one has no coordinates is not nil" do
      features = [
        %{
          "geometry" => %{
            "coordinates" => []
          }
        },
        %{
          "geometry" => %{
            "coordinates" => [[1, 0]]
          }
        }
      ]

      bounding_box = GeojsonUtils.calculate_bounding_box(features)

      assert bounding_box == [1, 0, 1, 0]
    end

    test "the bounding box of a single feature with a one-dimensional point does not raise an error" do
      feature = %{
        "geometry" => %{
          "coordinates" => [-1, 0]
        }
      }

      bounding_box = GeojsonUtils.calculate_bounding_box(feature)

      assert bounding_box == [-1, 0, -1, 0]
    end

    data_test "throws an exception when feature has #{error_reason}" do
      Logger.debug(fn -> "Testing #{error_reason}" end)
      features = [%{"geometry" => %{"coordinates" => coordinates}}]

      assert_raise MalformedGeometryError, fn ->
        GeojsonUtils.calculate_bounding_box(features)
      end

      where([
        [:error_reason, :coordinates],
        ["malformed geometry", [[[-1, "a"], [4, 8], [4, 13], [-1, 13], [-1, 8]]]],
        ["null coordinate axes", [[[-1, nil], [4, 8], [4, 13], [nil, 13], [-1, 8]]]],
        ["missing coordinate axes", [[[-1], [4, 8], [4, 13], [13], [-1, 8]]]]
      ])
    end
  end
end
