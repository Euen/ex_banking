defmodule ExBanking.UserApi do
  alias ExBanking.{User, UserSupervisor, Account, UserServer}

  @registry UserRegistry
  @max_tasks_per_user 10
  @table :user_tasks

  @spec start_link(String.t()) :: {:ok, pid} | {:error, term()}
  def start_link(username) do
    name = via_tuple(username)
    GenServer.start_link(UserServer, username, name: name)
  end

  def create_user(username) do
    perform_call(%{username: username}, :create_user)
  end

  def deposit(username, amount, currency) do
    %{username: username, amount: amount, currency: currency}
    |> perform_call(:deposit)
  end

  def withdraw(username, amount, currency) do
    %{username: username, amount: amount, currency: currency}
    |> perform_call(:withdraw)
  end

  def get_balance(username, currency) do
    %{username: username, currency: currency}
    |> perform_call(:get_balance)
  end

  def send(from_user, to_user, amount, currency) do
    updates = %{username: from_user, amount: amount, currency: currency}

    with {:ok, act} <- Account.changeset(updates),
         {:ok, _user} <- User.changeset(%{username: to_user}),
         :ok <- add_task(from_user),
         :ok <- add_task(to_user),
         {:ok, _, _} = response <- call(from_user, {:send, to_user, act.amount, currency}) do
      remove_task(from_user)
      remove_task(to_user)
      response
    else
      {:error, %Ecto.Changeset{}} -> {:error, :wrong_arguments}
      {:error, {^from_user, _}} -> {:error, :too_many_requests_to_sender}
      {:error, {^to_user, _}} -> {:error, :too_many_requests_to_receiver}
      {:error, :user_does_not_exist} -> {:error, :sender_does_not_exist}
      error -> error
    end
  end

  # Private functions

  defp perform_call(params, action) do
    with {:ok, act} <- Account.changeset(params),
         :ok <- add_task(act.username) do
      response = call(act.username, action(action, params))
      remove_task(act.username)
      response
    else
      {:error, %Ecto.Changeset{}} -> {:error, :wrong_arguments}
      {:error, {_, :too_many_requests_to_user}} -> {:error, :too_many_requests_to_user}
    end
  end

  defp action(:create_user, atr), do: {:create_user, atr.username}
  defp action(:deposit, atr), do: {:deposit, atr.amount, atr.currency}
  defp action(:withdraw, atr), do: {:withdraw, atr.amount, atr.currency}
  defp action(:get_balance, atr), do: {:get_balance, atr.currency}

  defp remove_task(key) do
    :ets.update_counter(@table, key, {2, -1})
  end

  defp add_task(key) do
    case :ets.update_counter(@table, key, {2, 1}, {key, 1}) do
      tasks_num when tasks_num <= @max_tasks_per_user ->
        :ok

      _ ->
        {:error, {key, :too_many_requests_to_user}}
    end
  end

  defp call(username, action) do
    try do
      GenServer.call(via_tuple(username), action)
    catch
      _, _ ->
        UserSupervisor.start_child(username)
        GenServer.call(via_tuple(username), action)
    end
  end

  defp via_tuple(username) do
    {:via, Registry, {@registry, username}}
  end
end
