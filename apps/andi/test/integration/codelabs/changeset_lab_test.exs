defmodule Codelabs.Changesets do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.StructTools
  alias Codelabs.CodelabRepo
  alias Ecto.Changeset

  alias Codelabs.Person
  alias Codelabs.Address

  describe "Creating simple changesets" do
    test "A data structure can be created from a schema definition" do
      person = %Person{name: "bob"}

      assert person.name == "bob"
      assert person.age == nil
      assert person.id == nil
    end

    test "A changeset can be created from a data structure" do
      changes = %{}
      cast_fields = []
      person_changeset = Changeset.cast(%Person{}, changes, cast_fields)

      assert person_changeset.changes == %{}
      assert person_changeset.data == %Person{}
    end
  end

  describe "Registering changes, performing actions" do
    test "A changeset can register a change to be applied" do
      person = %Person{name: "Abe"}
      changes = %{name: "George"}
      cast_fields = [:name]
      person_changeset = Changeset.cast(person, changes, cast_fields)

      assert person_changeset.changes == %{name: "George"}
    end

    test "However, it does not modify the underlying data" do
      person = %Person{name: "Abe"}
      changes = %{name: "George"}
      cast_fields = [:name]
      person_changeset = Changeset.cast(person, changes, cast_fields)

      assert person_changeset.data == person
    end

    test "Until, you perform an action, which 'drops' you out of the changeset" do
      person = %Person{name: "Abe"}
      changes = %{name: "George"}
      cast_fields = [:name]

      {:ok, data} =
        Changeset.cast(person, changes, cast_fields)
        |> Changeset.apply_action(:update)

      assert data.name == "George"
    end

    test "Registering a new change overwrites the fields being changed, but leaves the rest" do
      person = %Person{name: "Abe"}
      changes = %{name: "George", age: 123}
      cast_fields = [:name, :age]
      first_changeset = Changeset.cast(person, changes, cast_fields)

      assert first_changeset.changes == %{name: "George", age: 123}

      more_changes = %{name: "Bob"}
      second_changeset = Changeset.cast(first_changeset, more_changes, cast_fields)

      assert second_changeset.changes == %{name: "Bob", age: 123}
    end
  end

  describe "Errors - Validations" do
    test "Using ecto provided validations will both add errors and changes" do
      person = %Person{}
      changes = %{name: "turtle"}
      cast_fields = [:name]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)
                         |> Changeset.validate_length(:name, is: 3)

      assert invalid_person_changeset.changes == %{name: "turtle"}
      assert invalid_person_changeset.errors == [
               {:name, {"should be %{count} character(s)", [count: 3, validation: :length, kind: :is, type: :string]}}
             ]
    end

    test "IMPORTANT! - validate_required will not be added as changes" do
      #This causes behavior where you cannot unselect fields if using purely changesets
      person = %Person{name: "turtle"}
      changes = %{name: nil}
      cast_fields = [:name]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)
                                 |> Changeset.validate_required([:name])

      assert invalid_person_changeset.changes == %{}
      assert invalid_person_changeset.errors == [
               name: {"can't be blank", [validation: :required]}
             ]
    end

    test "Custom validation can be used" do
      custom_validation = fn changeset ->
        name = changeset |> Changeset.get_field(:name)

        case name do
          "turtle" -> changeset
          _ -> Changeset.add_error(changeset, :name, "not a turtle")
        end
      end

      person = %Person{}
      changes = %{name: "not a turtle"}
      cast_fields = [:name]

      invalid_person_changeset =
        Changeset.cast(person, changes, cast_fields)
        |> custom_validation.()

      assert invalid_person_changeset.changes == %{name: "not a turtle"}
      assert invalid_person_changeset.errors == [{:name, {"not a turtle", []}}]
    end

    # Important!
    test "Running ecto validations on underlying data does not work, only changes!" do
      person = %Person{name: "turtle"}
      changes = %{}
      cast_fields = [:name]

      invalid_person_changeset =
        Changeset.cast(person, changes, cast_fields)
        |> Changeset.validate_length(:name, is: 3)

      assert invalid_person_changeset.changes == %{}
      assert invalid_person_changeset.errors == []
    end

    #Important!
    test "Unless you use the force_changes flag when casting the underlying data" do
      person = %Person{name: "turtle", age: "not a number"}
      changes = %{}
      cast_fields = [:age, :name]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)

      changes_as_map = StructTools.to_map(invalid_person_changeset.data)
      valid_person_changeset = Changeset.cast(invalid_person_changeset, changes_as_map, cast_fields, force_changes: true)
          |> Changeset.validate_length(:name, is: 3)

      # Does not change existing fields
      assert valid_person_changeset.changes == %{name: "turtle"}
      # But does catch validations
      assert valid_person_changeset.errors == [
               {:name, {"should be %{count} character(s)", [count: 3, validation: :length, kind: :is, type: :string]}},
               {:age, {"is invalid", [type: :integer, validation: :cast]}}
             ]
      assert valid_person_changeset.data.age == "not a number"
    end
  end

  describe "Errors - Data Types" do
    test "A data structure allows for incorrect data types" do
      person = %Person{age: "not an int"}

      assert person.age == "not an int"
    end

    test "A changeset sometimes allows incorrect data types - if the data is already in the structure" do
      person = %Person{age: "not an int"}
      changes = %{}
      cast_fields = [:age]
      person_changeset = Changeset.cast(person, changes, cast_fields)

      assert person.age == "not an int"
    end

    test "However, a changeset can guard against incorrect data types, if applied as a change" do
      person = %Person{age: 20}
      changes = %{age: "not an integer"}
      cast_fields = [:age]
      person_changeset = Changeset.cast(person, changes, cast_fields)

      assert person_changeset.changes == %{}
      assert person_changeset.errors == [{:age, {"is invalid", [type: :integer, validation: :cast]}}]
    end

    # Important!
    test "Cast validations on underlying data does not work, only changes!" do
      person = %Person{age: "not a number"}
      changes = %{}
      cast_fields = [:age]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)

      assert invalid_person_changeset.changes == %{}
      assert invalid_person_changeset.errors == []
      assert invalid_person_changeset.data.age == "not a number"
    end

    test "A workaround is to apply the same underlying data on top of ITSELF" do
      person = %Person{age: "not a number"}
      changes = %{}
      cast_fields = [:age]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)

      changes_as_map = StructTools.to_map(invalid_person_changeset.data)
      valid_person_changeset = Changeset.cast(invalid_person_changeset, changes_as_map, cast_fields)

      # Does not change existing fields
      assert valid_person_changeset.changes == %{}
      # But does catch validations
      assert valid_person_changeset.errors == [{:age, {"is invalid", [type: :integer, validation: :cast]}}]
      assert valid_person_changeset.data.age == "not a number"
    end

    test "But this workaround does not catch ecto provided validations" do
      person = %Person{name: "turtle", age: "not a number"}
      changes = %{}
      cast_fields = [:age, :name]
      invalid_person_changeset = Changeset.cast(person, changes, cast_fields)

      changes_as_map = StructTools.to_map(invalid_person_changeset.data)
      valid_person_changeset = Changeset.cast(invalid_person_changeset, changes_as_map, cast_fields)
                               |> Changeset.validate_length(:name, is: 3)

      # Does not change existing fields
      assert valid_person_changeset.changes == %{}
      # But does catch validations
      assert valid_person_changeset.errors == [{:age, {"is invalid", [type: :integer, validation: :cast]}}]
      assert valid_person_changeset.data.age == "not a number"
    end
  end

  describe "Errors - Database writes" do
    test "Saving a child with an invalid parent association throws an error" do
      changeset = Address.changeset(%Address{}, %{person_id: Ecto.UUID.generate()})

      try do
        Repo.insert_or_update(changeset)
        flunk("Expected a foreign key constraint error")
      rescue
        constraint_error in Ecto.ConstraintError ->
          assert constraint_error.constraint == "address_person_id_fkey"
        error -> flunk("Unexpected error: #{error}}")
      end
    end

    test "Foreign key constraint validation are added as errors to the changeset, rather than throwing an error, but only AFTER a database operation" do
      changeset = Address.changeset(%Address{}, %{person_id: Ecto.UUID.generate()})
      constrained_changeset = changeset |> Changeset.foreign_key_constraint(:person_id)

      assert constrained_changeset.errors == []
      assert constrained_changeset.valid? == true

      {:error, failed_changeset} = Repo.insert_or_update(constrained_changeset)

      assert failed_changeset.errors == [person_id: {"does not exist", [constraint: :foreign, constraint_name: "address_person_id_fkey"]}]
      assert failed_changeset.valid? == false
    end

    test "However, saving a child with no parent association is fine" do
      changeset = Address.changeset(%Address{}, %{})

      {:ok, address} = Repo.insert_or_update(changeset)
    end

    test "Foreign key constraint validation allows for empty values" do
      changeset = Address.changeset(%Address{}, %{})
                  |> Changeset.foreign_key_constraint(:person_id)

      {:ok, address } = Repo.insert_or_update(changeset)
    end
  end

#  describe "Nested errors" do
#    test "Saving a parent with a child error" do
#      child_changes = %{street: "way too long of a street name to be valid - past 40 chars"}
#      parent_changeset = Person.changeset(%Person{}, %{addresses: [child_changes]})
#
#      try do
#        Repo.insert_or_update(parent_changeset)
#        flunk("Expected a foreign key constraint error")
#      rescue
#        constraint_error in Ecto.ConstraintError ->
#          assert constraint_error.constraint == "address_person_id_fkey"
#        error -> flunk("Unexpected error: #{error}}")
#      end
#    end
#  end

  describe "Inserting new data into a database" do
    # Migrations and general database management is a much larger topic.
    # Ideally, an entire codelab would be created to help understand how to use it
    # In the interest of keeping focused on changesets, I only added a migration
    # to the existing repo rather than splitting the migrations away from production.
    # I tried to create a Codelabs.Repo, but it got very messy

    test "A data structure can be written to a Repo via a changeset, which can be configured to automatically generate an id(See schema)" do
      person = %Person{}
      changes = %{}
      cast_fields = []
      person_changeset = Changeset.cast(%Person{}, changes, cast_fields)

      {:ok, data} = Repo.insert(person_changeset)

      assert data.id != nil
    end

    test "It will write the underlying data" do
      #Todo: check
      person = %Person{name: "turtle"}
      changes = %{}
      cast_fields = [:name]
      person_changeset = Changeset.cast(person, changes, cast_fields)
      {:ok, data} = Repo.insert(person_changeset)

      assert person_changeset.data.name == "turtle"
      assert data.name == "turtle"
    end

    test "Changes on a changeset will be applied" do
      person = %Person{name: "turtle"}
      changes = %{name: "george"}
      cast_fields = [:name]
      person_changeset = Changeset.cast(person, changes, cast_fields)

      {:ok, data} = Repo.insert(person_changeset)

      assert person_changeset.data.name == "turtle"
      assert person_changeset.changes.name == "george"
      assert data.name == "george"
    end

    test "A changeset with errors is rejected completely" do
      person = %Person{age: 123}
      changes = %{age: "not an int", name: "other"}
      cast_fields = [:age, :name]
      person_changeset_with_error = Changeset.cast(person, changes, cast_fields)

      {:error, rejected_changeset} = Repo.insert(person_changeset_with_error)

      assert person_changeset_with_error.errors == [{:age, {"is invalid", [type: :integer, validation: :cast]}}]
      assert person_changeset_with_error.changes == %{name: "other"}
      assert person_changeset_with_error.data.age == 123
      assert person_changeset_with_error.data.name == nil
      assert rejected_changeset.data.age == 123
      assert rejected_changeset.data.name == nil
    end
  end

  describe "updating data to the database" do
    test "Basic update" do
      person = %Person{name: "turtle"}
      changes = %{}
      cast_fields = [:name, :id]
      person_changeset = Changeset.cast(person, changes, cast_fields)
      {:ok, data} = Repo.insert(person_changeset)
      assert data.id != nil

      another_changeset = Changeset.cast(data, %{name: "bob"}, cast_fields)
      {:ok, data} = Repo.update(another_changeset)

      assert data.name == "bob"
    end

    # Extremely important and sneaky!
    # This problem become exaggerated when dealing with nested schemas
    test "Be careful to not apply the underlying data on top of a new changeset or the database will assume it an insert" do
      # Setup Existing Changeset
      person = %Person{name: "turtle"}
      changes = %{}
      cast_fields = [:name, :id]
      person_changeset = Changeset.cast(person, changes, cast_fields)
      {:ok, data} = Repo.insert(person_changeset)

      # Create a new changeset with the exact same data
      changes_as_map = StructTools.to_map(data)
      invalid_person_changeset = Changeset.cast(%Person{}, changes_as_map, cast_fields)
      # It now thinks you've changed data
      assert invalid_person_changeset.changes == %{id: data.id, name: "turtle"}

      # So updating the repo will fail since the data technically has no id
      assert invalid_person_changeset.data.id == nil

      try do
        result = Repo.update(invalid_person_changeset)
        flunk("Expected update to fail due to no primary key")
      rescue
        Ecto.NoPrimaryKeyValueError ->
          :ok
      end

      # Note: I believe building from partial data that includes an ID can result in
      # clearing nested schemas since the parent update would be valid.
      # Although, it may result in an attempt to insert over top of existing data and cause failures
      # This is hard to debug, so be careful to not build from partial/empty data unless you
      # are inserting. I'll try to write a test for this at some point.
    end
  end

  describe "Association/Nested schemas" do
    test "Nested schemas use the cast_assoc func instead of cast" do
      expected_street = "123 Wrong Way"
      address = %{street: expected_street}
      changes = %{name: "bob", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      assert person_changeset.changes.name == "bob"

      case person_changeset.changes.addresses do
        [child_changeset] ->
          # The new changes are registered in a child changeset
          assert child_changeset.changes.street == expected_street

          # The parent is not associated yet
          assert child_changeset.data.person_id == nil
          assert Map.has_key?(child_changeset.changes, :person_id) == false

          # The changeset detects this is a new child and decides to insert
          assert child_changeset.action == :insert

          # The data in the changeset is empty since it couldn't match an ID
          assert child_changeset.data.id == nil
          assert child_changeset.data.street == nil

          # No validations
          assert child_changeset.errors == []

        _ ->
          flunk("Expected a child changeset to be created")
      end
    end

    test "Inserting the nested changeset into a database will officially associate parent/child" do
      expected_street = "123 Wrong Way"
      address = %{street: expected_street}
      changes = %{name: "bob", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.insert(person_changeset)

      assert data.name == "bob"

      case data.addresses do
        [child_data] ->
          # The child data is correct
          assert child_data.street == expected_street

          # The child data is associated to parent via ID
          assert child_data.person_id == data.id

          # But the person field is not loaded by default
          assert child_data.person == %Ecto.Association.NotLoaded{__cardinality__: :one, __field__: :person, __owner__: Codelabs.Address}

        _ ->
          flunk("Expected child data to be extracted")
      end
    end

    test "Once inserted, you must be careful to not overwrite existing children!" do
      # Create the nested schema
      first_expected_street = "123 Wrong Way"
      address = %{street: first_expected_street}
      changes = %{name: "bob", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.insert(person_changeset)
      # Extract the child ID to prove it will be overwritten
      first_child_id =
        case data.addresses do
          [child] -> child.id
        end

      # Reference the inserted data, but forget to reference the child ID in changes
      second_expected_street = "456 Pickup Sticks"
      address = %{street: second_expected_street}
      changes = %{name: "george", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(data, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.update(person_changeset)

      case data.addresses do
        # Only one child exists
        [child] ->
          # The id has been overwritten!
          assert child.id != first_child_id
          # The name has been overwritten!
          assert child.street == second_expected_street

        _ ->
          flunk("Expected one child, which was overwritten")
      end
    end

    test "So, one deceptively incorrect way to update a child is to include the id in the changes" do
      # Create the nested schema
      first_expected_street = "123 Wrong Way"
      address = %{street: first_expected_street}
      changes = %{name: "bob", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.insert(person_changeset)
      # Extract the child ID to prove it will be overwritten
      first_child_id =
        case data.addresses do
          [child] -> child.id
        end

      second_expected_street = "456 Pickup Sticks"
      # Adding ID in the changes for the child is valid
      address = %{id: first_child_id, street: second_expected_street}
      changes = %{name: "george", addresses: [address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(data, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.update(person_changeset)

      case data.addresses do
        [child] ->
          # The id has not been overwritten
          assert child.id == first_child_id
          assert child.street == second_expected_street

        _ ->
          flunk("Expected one child, which was not overwritten")
      end
    end

    test "EXTREMELY IMPORTANT TEST! - However, if you do not include ALL children in changes, it will delete the other children" do
      first_expected_street = "123 Wrong Way"
      second_expected_street = "456 Pickup Sticks"
      first_address = %{street: first_expected_street}
      second_address = %{street: second_expected_street}
      changes = %{addresses: [first_address, second_address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.insert(person_changeset)

      first_child_id =
        case data.addresses do
          [first_child, second_child] -> first_child.id
        end

      second_child_id =
        case data.addresses do
          [first_child, second_child] -> second_child.id
        end

      third_expected_street = "789 This is fine"
      # Include the ID in the changes
      third_address = %{id: first_child_id, street: third_expected_street}
      # Include only the changed address in the change struct
      # Which will make the changeset assume you want to delete the others......
      changes = %{addresses: [third_address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(data, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.update(person_changeset)

      case data.addresses do
        [child] ->
          # It updated the first child correctly, but there is no second child now
          assert child.id == first_child_id
          assert child.street == third_expected_street
        _ ->
          flunk("Expected one child, which overwrote the other two!")
      end
    end

    test "Therefore, the only correct way to change the child from the parent is to create an empty change for all children..." do
      # Same setup as before - Insert two children
      first_expected_street = "123 Wrong Way"
      second_expected_street = "456 Pickup Sticks"
      first_address = %{street: first_expected_street}
      second_address = %{street: second_expected_street}
      changes = %{name: "bob", addresses: [first_address, second_address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.insert(person_changeset)

      first_child_id =
        case data.addresses do
          [first_child, second_child] -> first_child.id
        end

      second_child_id =
        case data.addresses do
          [first_child, second_child] -> second_child.id
        end

      third_expected_street = "789 This is fine"
      # Again, include the id in the change struct
      third_address = %{id: first_child_id, street: third_expected_street}
      # But now, we correctly map over the current addresses, creating empty change structs as needed
      modified_addresses =
        data.addresses
        |> Enum.map(fn
          %{id: id} when id == first_child_id -> third_address
          %{id: id} = other_address -> %{id: id}
        end)

      # Now we assign the collection of addresses as changes
      changes = %{addresses: modified_addresses}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(data, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, data} = Repo.update(person_changeset)

      case data.addresses do
        [first_child, second_child] ->
          assert first_child.id == first_child_id
          assert second_child.id == second_child_id
          # The street has been updated corretly!
          assert first_child.street == third_expected_street
          # The other children have been left alone!
          assert second_child.street == second_expected_street
        _ ->
          flunk("Expected one child, which overwrote the other two!")
      end
    end

    test "Admittedly, changing the child by itself is easier" do
      # Same setup as before - Insert two children
      first_expected_street = "123 Wrong Way"
      second_expected_street = "456 Pickup Sticks"
      first_address = %{street: first_expected_street}
      second_address = %{street: second_expected_street}
      changes = %{name: "bob", addresses: [first_address, second_address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, person_data} = Repo.insert(person_changeset)

      first_child =
        case person_data.addresses do
          [first_child, second_child] -> first_child
        end
      second_child =
        case person_data.addresses do
          [first_child, second_child] -> second_child
        end

      # When updating the child in isolation, you don't have to worry about ID
      third_expected_street = "789 This is fine"
      change_first_child = %{street: third_expected_street}
      first_child_changeset = Changeset.cast(first_child, change_first_child, [:street])
      {:ok, modified_first_child} = Repo.update(first_child_changeset)
      assert modified_first_child.id == first_child.id
      assert modified_first_child.street == third_expected_street

      #Also, when loading the parent, the data has changed and the other child exists
      parent = Repo.get(Person, person_data.id)
               |> Repo.preload([:addresses])
      case parent.addresses do
        [second_preloaded_child, first_preloaded_child] ->
          # The preloaded child has been modified
          assert first_preloaded_child.id == first_child.id
          assert first_preloaded_child.street == third_expected_street
          # The other preloaded child still exists, unmodified
          assert second_preloaded_child.id == second_child.id
          assert second_preloaded_child.street == second_child.street
      end
    end

    test "However, changing the child in isolation leads to an even worse scenario than accidentally overwritting children - Out of sync data and race conditions!" do
      # This test will:
      # 1 - Insert two children
      # 2 - Retain the inserted parent for future changes
      # 3 - Change the child in isolation
      # 4 - Change the child from the parent as well
      # 5 - Update the parent
      # 6 - Show that the isolated child change has now been overwritten by the out-of-sync parent update

      # Same setup as before - Insert two children
      first_expected_street = "123 Wrong Way"
      second_expected_street = "456 Pickup Sticks"
      first_address = %{street: first_expected_street}
      second_address = %{street: second_expected_street}
      changes = %{name: "bob", addresses: [first_address, second_address]}
      cast_fields = [:name]

      person_changeset =
        Changeset.cast(%Person{}, changes, cast_fields)
        |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)

      {:ok, person_data} = Repo.insert(person_changeset)

      first_child =
        case person_data.addresses do
          [first_child, second_child] -> first_child
        end
      second_child =
        case person_data.addresses do
          [first_child, second_child] -> second_child
        end
      first_child_id = first_child.id
      assert first_child_id != nil

      # Change the child in isolation - Likely in a separate LiveView
      third_expected_street = "789 This is fine"
      change_first_child = %{street: third_expected_street}
      first_child_changeset = Changeset.cast(first_child, change_first_child, [:street])
      {:ok, modified_first_child} = Repo.update(first_child_changeset)
      assert modified_first_child.id == first_child_id
      assert modified_first_child.street == third_expected_street

      # Change the child from the parent as well
      # Again, include the id, map over existing children, and assign the entire collection
      fourth_expected_street = "Out of Digits Ct"
      child_changes = %{id: first_child_id, street: fourth_expected_street}
      modified_addresses =
        person_data.addresses
        |> Enum.map(fn
          %{id: id} when id == first_child_id -> child_changes
          %{id: id} -> %{id: id}
        end)
      # Update the parent
      parent_changes = %{addresses: modified_addresses}
      parent_changeset = Changeset.cast(person_data, parent_changes, cast_fields)
                         |> Changeset.cast_assoc(:addresses, with: &Address.changeset/2)
      updated_parent = Repo.update(parent_changeset)


      # Show that the isolated child change have now been overwritten by the out-of-sync parent update
      parent = Repo.get(Person, person_data.id)
               |> Repo.preload([:addresses])
      case parent.addresses do
        [second_preloaded_child, first_preloaded_child] ->
          assert first_preloaded_child.id == first_child_id
          # The isolated change has been reverted!
          # It should be the third street here, but it was overwritten by out-dated data
          assert first_preloaded_child.street == fourth_expected_street
          # The other preloaded child still exists, unmodified
          assert second_preloaded_child.id == second_child.id
          assert second_preloaded_child.street == second_child.street
      end
    end
  end




  ## ======================================= ##
  ## The recommended way to use a changeset
  ## ======================================= ##

  describe "changeset/2" do
    test "Can creates a new changeset with current data and no changes detected" do
      bob = %Person{name: "bob", age: 55}
      no_changes = %{}
      changeset = Person.changeset(bob, no_changes)

      assert changeset.data.age == 55
      assert changeset.data.name == "bob"
      assert changeset.changes == %{}
    end

    test "Can create a new changeset with current data with additional changes" do
      bob = %Person{name: "bob", age: 55}
      changes = %{name: "turtle"}
      changeset = Person.changeset(bob, changes)

      assert changeset.data.age == 55
      assert changeset.data.name == "bob"
      assert changeset.changes == %{name: "turtle"}
    end

    test "Should only run basic validations from cast and does not include as a change if invalid" do
      # This is an opinion, but I think this makes the most sense
      # Cast gives us base-line detection of something fundamentally wrong
      # An error from cast is never okay
      # Mainly wrong data types and incompatible nested schema data
      # However, it allows for multiple types of validation that we can piecemeal
      # For example, when inserting a draft, we only care about basic validation
      # But when publishing or handling an API call, we care about the full validation
      # Furthermore, we may care about UI validation only within elixir
      # In all these scenarios, we want to know if the data type is wrong
      # or if the nested schemas are constructed wrong

      bob = %Person{name: "bob", age: 55}
      changes = %{age: "not a number"}
      changeset = Person.changeset(bob, changes)

      assert changeset.data.age == 55
      assert changeset.data.name == "bob"
      assert changeset.changes == %{}
      assert changeset.errors == [{:age, {"is invalid", [type: :integer, validation: :cast]}}]
    end
  end

  describe "validate/1" do
    test "should validate changes" do
      changes = %{name: "way too long of a name"}

      changeset =
        Person.changeset(%Person{}, changes)
        |> Person.validate()

      assert changeset.changes == changes
      assert changeset.errors == [
               {:name, {"should be at most %{count} character(s)", [count: 10, validation: :length, kind: :max, type: :string]}}
             ]
    end

    test "should validate underlying data" do
      # This allows us to save drafts with invalid data, but then validate for publish/UI
      # Remember, the underlying data should represent what is in the database
      person = %Person{name: "way too long of a name"}

      changeset =
        Person.changeset(person, %{})
        |> Person.validate()

      assert changeset.changes == %{}
      assert changeset.errors == [
               {:name, {"should be at most %{count} character(s)", [count: 10, validation: :length, kind: :max, type: :string]}}
             ]
    end

    test "should clear previous errors of the changed field" do
      invalid_change = %{name: "way too long of a name"}

      changeset =
        Person.changeset(%Person{}, invalid_change)
        |> Person.validate()

      assert changeset.changes == invalid_change
      assert changeset.errors == [
               {:name, {"should be at most %{count} character(s)", [count: 10, validation: :length, kind: :max, type: :string]}}
             ]

      valid_changes = %{name: "bob"}

      validated_changeset =
        Person.changeset(changeset, valid_changes)
        |> Person.validate()

      assert validated_changeset.changes == valid_changes
      assert validated_changeset.errors == []
    end
  end


end
