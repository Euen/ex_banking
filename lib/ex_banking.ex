defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """

  alias ExBanking.UserApi

  @doc """
  Create a new User

  ## Examples

      iex> ExBanking.create_user("user@test.com")
      :ok

      iex> ExBanking.create_user("user@test.com")
      {:error, :user_already_exists}

      iex> ExBanking.create_user("invalid_username")
      {:error, :wrong_arguments}

      iex> ExBanking.create_user("")
      {:error, :wrong_arguments}

  """
  @spec create_user(String.t()) :: :ok, {:error, :wrong_arguments | :user_already_exists}
  def create_user(username) do
    UserApi.create_user(username)
  end

  @doc """
  Deposit an amount and update User balance for the corresponding currency

  ## Examples

      iex> ExBanking.deposit("user@test.com", 20, "USD")
      {:ok, 20.00}

      iex> ExBanking.deposit("user@test.com", -20, "USD")
      {:error, :wrong_arguments}

      iex> ExBanking.deposit("non_existent", 20, "USD")
      {:error, :user_does_not_exist}

  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(username, amount, currency) do
    UserApi.deposit(username, amount, currency)
  end

  @doc """
  Withdraw an amount and update User balance for the corresponding currency

  ## Examples

      iex> ExBanking.withdraw("user@test.com", 20, "USD")
      {:ok, 80.00}

      iex> ExBanking.withdraw("user@test.com", 20000, "USD")
      {:error, :not_enough_money}

      iex> ExBanking.withdraw("user@test.com", -20, "USD")
      {:error, :wrong_arguments}

  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(username, amount, currency) do
    UserApi.withdraw(username, amount, currency)
  end

  @doc """
  Gets the user balance for a given currency

  ## Examples

      iex> ExBanking.get_balance("user@test.com", "USD")
      {:ok, 80.00}

      iex> ExBanking.get_balance("non_existent", "USD")
      {:error, :user_does_not_exist}

      iex> ExBanking.get_balance("user@test.com", "non_existent")
      {:error, :wrong_arguments}

  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(username, currency) do
    UserApi.get_balance(username, currency)
  end

  @doc """
  Send money from one User to another

  ## Examples

      iex> ExBanking.send("sender", "receiver", 100, "USD")
      {:ok, 0.0, 100}

  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency) do
    UserApi.send(from_user, to_user, amount, currency)
  end
end
