defmodule Jsonpatch.Operation.Replace do
  @moduledoc """
  The replace module helps replacing values in maps and structs by paths.

  ## Examples

      iex> add = %Jsonpatch.Operation.Replace{path: "/a/b", value: 1}
      iex> target = %{"a" => %{"b" => 2}}
      iex> Jsonpatch.Operation.apply_op(add, target)
      %{"a" => %{"b" => 1}}
  """

  @enforce_keys [:path, :value]
  defstruct [:path, :value]
  @type t :: %__MODULE__{path: String.t(), value: any}
end

defimpl Jsonpatch.Operation, for: Jsonpatch.Operation.Replace do
  @spec apply_op(Jsonpatch.Operation.Replace.t(), map | Jsonpatch.error()) :: map
  def apply_op(%Jsonpatch.Operation.Replace{path: path, value: value}, %{} = target) do
    {final_destination, last_fragment} = Jsonpatch.PathUtil.get_final_destination(target, path)
    updated_final_destination = do_update(final_destination, last_fragment, value)
    Jsonpatch.PathUtil.update_final_destination(target, updated_final_destination, path)
  end

  def apply_op(_, {:error, _, _} = error), do: error

  # ===== ===== PRIVATE ===== =====

  defp do_update(%{} = final_destination, last_fragment, value) do
    if Map.has_key?(final_destination, last_fragment) do
      Map.replace!(final_destination, last_fragment, value)
    else
      {:error, :invalid_path, last_fragment}
    end
  end

  defp do_update(final_destination, last_fragment, value) when is_list(final_destination) do
    case Integer.parse(last_fragment) do
      :error ->
        {:error, :invalid_index, last_fragment}

      {index, _} ->
        case List.pop_at(final_destination, index) do
          {nil, _} -> {:error, :invalid_index, last_fragment}
          _ -> List.replace_at(final_destination, index, value)
        end
    end
  end
end
