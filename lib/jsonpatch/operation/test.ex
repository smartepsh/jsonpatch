defmodule Jsonpatch.Operation.Test do
  @moduledoc """
  A test operation in a JSON patch prevents the patch application or allows it.

  ## Examples

      iex> test = %Jsonpatch.Operation.Test{path: "/x/y", value: "Bob"}
      iex> target = %{"x" => %{"y" => "Bob"}}
      iex> Jsonpatch.Operation.apply_op(test, target)
      %{"x" => %{"y" => "Bob"}}
  """

  @enforce_keys [:path, :value]
  defstruct [:path, :value]
  @type t :: %__MODULE__{path: String.t(), value: any}
end

defimpl Jsonpatch.Operation, for: Jsonpatch.Operation.Test do
  @spec apply_op(Jsonpatch.Operation.Test.t(), map | Jsonpatch.error()) :: map()
  def apply_op(%Jsonpatch.Operation.Test{path: path, value: value}, %{} = target) do
    if Jsonpatch.PathUtil.get_final_destination(target, path) |> do_test(value) do
      target
    else
      {:error, :test_failed, "Expected value '#{value}' at '#{path}'"}
    end
  end

  def apply_op(_, {:error, _, _} = error), do: error

  # ===== ===== PRIVATE ===== =====

  defp do_test({%{} = target, last_fragment}, value) do
    Map.get(target, last_fragment) == value
  end

  defp do_test({target, last_fragment}, value) when is_list(target) do
    case Integer.parse(last_fragment) do
      {index, _} ->
        {target_val, _index} =
          Enum.with_index(target)
          |> Enum.find(fn {_, i} -> i == index end)

        target_val == value

      :error ->
        false
    end
  end
end
