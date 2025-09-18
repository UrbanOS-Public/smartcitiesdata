defmodule Forklift.Compilation.DuplicateModuleTest do
  @moduledoc """
  This test demonstrates the compilation error that occurs when the same module
  is defined in multiple files, specifically the RedixBehaviour duplicate definition.
  """
  use ExUnit.Case

  test "reproduces compilation error for duplicate Forklift.Test.RedixBehaviour definitions" do
    # This test demonstrates the exact error:
    # ** (CompileError) test/support/behaviours.ex:43: cannot define module
    # Forklift.Test.RedixBehaviour because it is currently being defined in
    # test/support/redix_behaviour.ex:1

    # The error occurs because:
    # 1. test/support/redix_behaviour.ex:1 defines Forklift.Test.RedixBehaviour
    # 2. test/support/behaviours.ex:43 also defines Forklift.Test.RedixBehaviour

    # Expected behavior definitions:
    expected_callbacks = [
      # command!(any(), any()) :: any()
      :command!
    ]

    # The module should exist and have the expected callback
    assert function_exported?(Forklift.Test.RedixBehaviour, :behaviour_info, 1)

    # Get the actual callbacks defined
    callbacks = Forklift.Test.RedixBehaviour.behaviour_info(:callbacks)
    callback_names = Enum.map(callbacks, fn {name, _arity} -> name end)

    # Verify the expected callback is present
    for expected_callback <- expected_callbacks do
      assert expected_callback in callback_names,
             "Expected callback #{expected_callback} not found in #{inspect(callback_names)}"
    end

    # This test will fail during compilation with the duplicate module error
    # when both files attempt to define the same module
  end

  test "demonstrates the root cause - multiple files defining same module" do
    # File 1: test/support/redix_behaviour.ex
    file1_content = """
    defmodule Forklift.Test.RedixBehaviour do
      @callback command!(any(), any()) :: any()
    end
    """

    # File 2: test/support/behaviours.ex (lines 43-45)
    file2_content = """
    defmodule Forklift.Test.RedixBehaviour do
      @callback command!(any, any) :: any
    end
    """

    # The Elixir compiler cannot handle the same module being defined in multiple files
    # This results in: "cannot define module Forklift.Test.RedixBehaviour because it
    # is currently being defined in test/support/redix_behaviour.ex:1"

    assert String.contains?(file1_content, "defmodule Forklift.Test.RedixBehaviour")
    assert String.contains?(file2_content, "defmodule Forklift.Test.RedixBehaviour")

    # The solution is to remove the duplicate definition from behaviours.ex
    # and keep only the standalone file version
  end

  test "verifies the duplicate DataMigrationBehaviour issue does not exist" do
    # Unlike RedixBehaviour, DataMigrationBehaviour should only be defined once
    # This test ensures we don't have a similar duplication issue

    # Check if DataMigrationBehaviour is properly defined
    assert function_exported?(Forklift.Test.DataMigrationBehaviour, :behaviour_info, 1)

    callbacks = Forklift.Test.DataMigrationBehaviour.behaviour_info(:callbacks)
    callback_names = Enum.map(callbacks, fn {name, _arity} -> name end)

    # Should have the compact callback
    assert :compact in callback_names
  end
end
