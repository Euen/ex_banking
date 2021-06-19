defmodule ExBanking.UserServer do
  use GenServer

  alias ExBanking.{Users, Accounts}

  @type t() :: %__MODULE__{:username => String.t()}
  @enforce_keys [:username]
  defstruct [:username]

  @table :user_tasks
  @inactivity_threshold 2000

  def init(username) do
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{username: username}}
  end

  def handle_call({:create_user, username}, _from, state) do
    response =
      case Users.create(username) do
        {:ok, _} -> :ok
        error -> error
      end

    {:reply, response, state, @inactivity_threshold}
  end

  def handle_call({:deposit, amount, currency}, _from, state) do
    response =
      case Accounts.increment_balance(state.username, amount, currency) do
        {:ok, %{balance: balance}} -> {:ok, round2(balance)}
        error -> error
      end

    {:reply, response, state, @inactivity_threshold}
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    response =
      case Accounts.decrement_balance(state.username, amount, currency) do
        {:ok, %{balance: balance}} -> {:ok, round2(balance)}
        error -> error
      end

    {:reply, response, state, @inactivity_threshold}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    response =
      case Accounts.get_by_currency(state.username, currency) do
        {:ok, %{balance: balance}} -> {:ok, round2(balance)}
        error -> error
      end

    {:reply, response, state, @inactivity_threshold}
  end

  def handle_call({:send, to_user, amount, currency}, _from, state) do
    response =
      case Accounts.send(state.username, to_user, amount, currency) do
        {:ok, {%{balance: from_balance}, %{balance: to_balance}}} ->
          {:ok, round2(from_balance), round2(to_balance)}

        error ->
          error
      end

    {:reply, response, state, @inactivity_threshold}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info(_, state), do: {:noreply, state, @inactivity_threshold}

  def terminate(_reason, state) do
    :ets.delete(@table, state.username)
  end

  defp round2(value) when is_float(value), do: Float.round(value, 2)
  defp round2(value), do: value
end
