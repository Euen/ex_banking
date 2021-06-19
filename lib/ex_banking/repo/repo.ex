defmodule ExBanking.Repo do
  @spec write(Memento.Table.record()) ::
          {:ok, Memento.Table.record() | no_return()}
          | {:error, any()}
          | Memento.Table.record()
          | no_return()
  def write(data) do
    if Memento.Transaction.inside?() do
      Memento.Query.write(data, lock: :write)
    else
      Memento.transaction(fn -> Memento.Query.write(data, lock: :write) end)
    end
  end

  @spec read(Memento.Table.name(), any()) :: {:ok, Memento.Table.record() | nil} | {:error, any()}
  def read(entity, field) do
    Memento.transaction(fn -> Memento.Query.read(entity, field) end)
  end

  @spec all(Memento.Table.name()) :: {:ok, [Memento.Table.record()]} | {:error, any()}
  def all(entity) do
    Memento.transaction(fn -> Memento.Query.all(entity) end)
  end

  @spec execute_in_transaction(fun()) :: {:ok, any()} | {:error, any()}
  def execute_in_transaction(query) do
    case Memento.transaction(query) do
      {:ok, {:error, _} = err_res} -> err_res
      {:ok, _} = ok_res -> ok_res
      {:error, _} = err_res -> err_res
    end
  end
end
