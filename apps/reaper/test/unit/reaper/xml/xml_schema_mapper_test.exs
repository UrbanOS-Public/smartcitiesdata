defmodule Reaper.XmlSchemaMapperTest do
  use ExUnit.Case, async: true

  alias Reaper.XmlSchemaMapper

  @record """
  <person>
     <firstName>John</firstName>
     <age>55</age>
     <address>
       <street>Main</street>
     </address>
     <pets>
       <pet name="Simon" age="10"></pet>
       <pet name="Sally" age="12"></pet>
     </pets>
   </person>
  """

  describe "map/2" do
    test "extracts string" do
      schema = [
        %{name: "first_name", type: "string", selector: "./firstName/text()"}
      ]

      assert XmlSchemaMapper.map(@record, schema) == %{"first_name" => "John"}
    end

    test "extracts nested data" do
      schema = [
        %{name: "first_name", type: "string", selector: "./firstName/text()"},
        %{
          name: "address_of_person",
          type: "map",
          subSchema: [
            %{name: "street_name", type: "string", selector: "./address/street/text()"}
          ]
        }
      ]

      assert XmlSchemaMapper.map(@record, schema) == %{
               "first_name" => "John",
               "address_of_person" => %{"street_name" => "Main"}
             }
    end

    test "extracts list" do
      schema = [
        %{name: "pets_of_person", type: "list", itemType: "string", selector: "./pets/pet/@name"}
      ]

      assert XmlSchemaMapper.map(@record, schema) == %{"pets_of_person" => ["Simon", "Sally"]}
    end

    test "extracts list of maps" do
      schema = [
        %{
          name: "pets_of_person",
          type: "list",
          itemType: "map",
          selector: "./pets/pet",
          subSchema: [
            %{name: "pet_name", type: "string", selector: "./@name"},
            %{name: "pet_age", type: "string", selector: "./@age"}
          ]
        }
      ]

      assert XmlSchemaMapper.map(@record, schema) == %{
               "pets_of_person" => [
                 %{"pet_age" => "10", "pet_name" => "Simon"},
                 %{"pet_age" => "12", "pet_name" => "Sally"}
               ]
             }

      %{"pets_of_person" => pets} = XmlSchemaMapper.map(@record, schema)
      assert Enum.member?(pets, %{"pet_age" => "10", "pet_name" => "Simon"})
      assert Enum.member?(pets, %{"pet_age" => "12", "pet_name" => "Sally"})
      assert length(pets) == 2
    end
  end
end
