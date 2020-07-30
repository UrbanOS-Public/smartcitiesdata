defmodule Definition.Schema.Type do
  @moduledoc """
  Defines specifications according to the Norm
  library for `string`, `required_string`, `id`, and `version`
  """

  import Norm
  import Definition.Schema.Validation

  @type spec :: Norm.Conformer.Conformable.t()

  @spec required_string() :: spec
  def required_string do
    spec(is_binary() and not_empty?())
  end

  @spec lowercase_string() :: spec
  def lowercase_string() do
    %Norm.Core.Spec.And{
      left: %Norm.Core.Spec.And{
        left: spec(is_binary()),
        right: spec(not_empty?())
      },
      right: %Definition.Schema.Type.Lowercase{}
    }
  end

  @spec string() :: spec
  def string, do: spec(is_binary())

  @spec version(expected :: integer) :: spec
  def version(expected) do
    spec(fn v -> v == expected end)
  end

  @spec id() :: spec
  def id, do: required_string()

  @spec of_struct(module) :: spec
  def of_struct(module) do
    spec(fn
      %m{} -> m == module
      _ -> false
    end)
  end

  @spec map() :: spec
  def map() do
    spec(fn
      %{__struct__: _} -> false
      x -> is_map(x)
    end)
  end

  def access_path do
    one_of([spec(is_binary()), coll_of(spec(is_binary()))])
  end

  @spec impl_of(module) :: spec
  def impl_of(protocol) do
    spec(fn value ->
      case protocol.impl_for(value) do
        nil -> false
        _ -> true
      end
    end)
  end
end
