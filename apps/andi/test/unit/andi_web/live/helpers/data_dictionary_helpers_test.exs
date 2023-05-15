defmodule AndiWeb.Helpers.DataDictionaryHelpersTest do
  use ExUnit.Case

  alias AndiWeb.Helpers.DataDictionaryHelpers

  describe "parse_xml/2" do
    test "parses xml text into a map with converted types" do
      xml_text = "<?xml version=\"1.0\"?><dataroot><trueorfalse>true</trueorfalse><anint>123</anint><afloat>12.3</afloat></dataroot>"

      expected = [
        %{
          "dataroot" => %{
            "trueorfalse" => true,
            "anint" => 123,
            "afloat" => 12.3
          }
        }
      ]

      actual = DataDictionaryHelpers.parse_xml(xml_text)

      assert actual == expected
    end
  end

  defp nested_xml_with_types() do
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <root>
    <data1>
      <BOOLean>true</BOOLean>
      <daTe>20230502</daTe>
      <INTeger>22</INTeger>
      <float>33.3</float>
      <STRing>hello</STRing>
      <List>
        <THING>
          <subthing>I'm a subthing</subthing>
          <subint>232</subint>
        </THING>
        <THING>
          <subthing>I'm a subthing</subthing>
          <subint>454</subint>
        </THING>
      </List>
    </data1>
    <data1>
      <BOOLean>true</BOOLean>
      <daTe>2023-05-02</daTe>
      <INTeger>22</INTeger>
      <float>33.3</float>
      <STRing>hello</STRing>
      <List>
        <THING>
          <subthing>I'm a subthing</subthing>
          <subint>232</subint>
        </THING>
        <THING>
          <subthing>I'm a subthing</subthing>
          <subint>454</subint>
        </THING>
      </List>
    </data1>
    </root>"
  end
end
