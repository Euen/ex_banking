defmodule ExBanking.Accounts do
  alias ExBanking.{Account, User, Users, Repo}

  def increment_balance(username, amount, currency) do
    fn ->
      changes = %{username: username, currency: currency, balance: amount, amount: amount}

      with {:ok, act} <- Account.changeset(changes),
           :ok <- Users.get(act.username) do
        do_update_user_balance(act.username, act.amount, act.currency)
      else
        {:error, %Ecto.Changeset{}} -> {:error, :wrong_arguments}
        {:error, {_, reason}} -> {:error, reason}
      end
    end
    |> Repo.execute_in_transaction()
  end

  def decrement_balance(username, amount, currency) do
    fn ->
      changes = %{username: username, currency: currency, balance: amount}

      with {:ok, act} <- Account.changeset(changes),
           :ok <- Users.get(act.username),
           {:ok, %{balance: balance} = act} <- do_get_by_currency(username, currency),
           true <- balance - amount >= 0 do
        Repo.write(%{act | balance: balance - amount})
      else
        {:error, {_, reason}} -> {:error, reason}
        {:error, _} -> {:error, :wrong_arguments}
        false -> {:error, :not_enough_money}
      end
    end
    |> Repo.execute_in_transaction()
  end

  def get_by_currency(username, currency) do
    fn ->
      changes = %{username: username, currency: currency}

      with {:ok, _} <- Account.changeset(changes),
           :ok <- Users.get(username),
           {:ok, account} <- do_get_by_currency(username, currency) do
        account
      else
        {:error, :wrong_arguments} -> {:error, :wrong_arguments}
        {:error, {_, reason}} -> {:error, reason}
        {:error, _} -> {:error, :wrong_arguments}
      end
    end
    |> Repo.execute_in_transaction()
  end

  def send(from_user, to_user, amount, currency) do
    fn ->
      changes = %{username: from_user, amount: amount, currency: currency}

      with {:ok, _} <- Account.changeset(changes),
           {:ok, _} <- User.changeset(%{username: to_user}),
           :ok <- Users.get(from_user),
           :ok <- Users.get(to_user),
           {:ok, %{balance: balance} = from_account} <- do_get_by_currency(from_user, currency),
           true <- balance - amount >= 0 do
        to_account = do_update_user_balance(to_user, amount, currency)

        from_account = Repo.write(%{from_account | balance: balance - amount})

        {from_account, to_account}
      else
        {:error, %Ecto.Changeset{}} -> {:error, :wrong_arguments}
        {:error, {^from_user, _}} -> {:error, :sender_does_not_exist}
        {:error, {^to_user, _}} -> {:error, :receiver_does_not_exist}
        {:error, :wrong_arguments} -> {:error, :wrong_arguments}
        false -> {:error, :not_enough_money}
      end
    end
    |> Repo.execute_in_transaction()
  end

  defp do_get_by_currency(username, currency) do
    guards = [{:==, :username, username}, {:==, :currency, currency}]

    case Memento.Query.select(Account, guards, lock: :write) do
      [] -> {:error, :wrong_arguments}
      [account] -> {:ok, account}
    end
  end

  def do_update_user_balance(username, amount, currency) do
    case do_get_by_currency(username, currency) do
      {:error, _} ->
        Repo.write(%Account{username: username, balance: amount, currency: currency})

      {:ok, act} ->
        Repo.write(%{act | balance: act.balance + amount})
    end
  end
end
