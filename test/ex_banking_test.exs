defmodule ExBankingTest do
  use ExUnit.Case

  alias ExBanking.{Repo, User, Account, Accounts}
  # doctest ExBanking

  @registry UserRegistry

  setup do
    %{username: random_user()}
  end

  describe "create_user/1" do
    test "creates a new user" do
      username = random_name()

      assert [] == Registry.lookup(@registry, username)
      assert :ok = ExBanking.create_user(username)
      assert [{pid, _}] = Registry.lookup(@registry, username)

      # needed to wait until the server is ready and the insertion can be tested
      :sys.get_state(pid)

      assert {:ok, %User{username: ^username}} = Repo.read(User, username)
    end

    test "it fails when the arguments are invalid" do
      assert {:error, :wrong_arguments} == ExBanking.create_user("")
    end

    test "it fails when the user already exist", %{username: username} do
      assert {:error, :user_already_exists} == ExBanking.create_user(username)
    end
  end

  describe "deposit/3" do
    test "it makes a deposit and increment the user balance", %{username: username} do
      assert {:ok, 40.50} = ExBanking.deposit(username, 40.50, "USD")
      assert {:ok, 51.00} = ExBanking.deposit(username, 10.50, "USD")
      assert {:ok, 5.67} = ExBanking.deposit(username, 5.6666, "ARS")
    end

    test "it fails when the arguments are invalid" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("", 50, "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit("user@test.com", -50, "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit("user@test.com", 50, "")
      # assert {:error, :wrong_arguments} == ExBanking.deposit("user@test.com", 50, 30)
    end

    test "it fails when the user does not exists" do
      assert {:error, :user_does_not_exist} == ExBanking.deposit("non_existent", 30, "USD")
    end

    test "it fails if the user make too many requests in a short period of time", %{
      username: username
    } do
      execute_async(11, :deposit, [username, 10, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> assert

      # After some time when the tasks finish, the user is able to continue with new tasks
      execute_async(5, :deposit, [username, 10, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> refute
    end
  end

  describe "withdraw/3" do
    test "it makes a withdraw and decrement the balance", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      ExBanking.deposit(username, 500, "ARS")

      assert {:ok, 700} = ExBanking.withdraw(username, 300, "USD")
      assert {:ok, 449.5} = ExBanking.withdraw(username, 50.50, "ARS")
      assert {:ok, 0.0} = ExBanking.withdraw(username, 449.5, "ARS")
    end

    test "it fails when the arguments are invalid", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")

      assert {:error, :wrong_arguments} = ExBanking.withdraw("", 300, "USD")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(username, -50.50, "USD")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(username, 500, "")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(username, 10, "ARS")
    end

    test "it fails when the user does not exists" do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw("non_existent", 30, "USD")
    end

    test "if fails when there is not enough balance in the account", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(username, 1000.01, "USD")
    end

    test "it fails if the user make too many requests in a short period of time", %{
      username: username
    } do
      ExBanking.deposit(username, 1000, "USD")

      execute_async(11, :withdraw, [username, 62.5, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> assert

      # After some time when the tasks finish, the user is able to continue with new tasks
      execute_async(5, :withdraw, [username, 62.5, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> refute
    end
  end

  describe "get_balance/2" do
    test "it retrieves the user balance for a given currency", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      assert {:ok, 1000} = ExBanking.get_balance(username, "USD")
      ExBanking.withdraw(username, 600, "USD")
      assert {:ok, 400} = ExBanking.get_balance(username, "USD")
    end

    test "it fails when the arguments are invalid", %{username: username} do
      assert {:error, :wrong_arguments} = ExBanking.get_balance("", "USD")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(username, "")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(username, "USD")
    end

    test "it fails when the user does not exists" do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance("non_existent", "USD")
    end

    test "it fails if the user make too many requests in a short period of time", %{
      username: username
    } do
      ExBanking.deposit(username, 1000, "USD")

      execute_async(11, :get_balance, [username, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> assert

      # After some time when the tasks finish, the user is able to continue with new tasks
      execute_async(5, :get_balance, [username, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_user})
      |> refute
    end
  end

  describe "send/4" do
    test "it send money from one user to another", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      receiver = random_name()
      ExBanking.create_user(receiver)

      assert {:ok, 400, 600} = ExBanking.send(username, receiver, 600, "USD")
      assert {:ok, 200, 800} = ExBanking.send(username, receiver, 200, "USD")
    end

    test "it fails when the arguments are invalid", %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      receiver = random_name()
      ExBanking.create_user(receiver)

      assert {:error, :wrong_arguments} = ExBanking.send("", receiver, 600, "USD")
      assert {:error, :wrong_arguments} = ExBanking.send(username, "", 600, "USD")
      assert {:error, :wrong_arguments} = ExBanking.send(username, receiver, -600, "USD")
      assert {:error, :wrong_arguments} = ExBanking.send(username, receiver, 600, "")
      assert {:error, :wrong_arguments} = ExBanking.send(username, receiver, 600, "ARS")
    end

    test "if fails when there is not enough balance in the account", %{username: username} do
      ExBanking.deposit(username, 10, "USD")
      receiver = random_name()
      ExBanking.create_user(receiver)

      assert {:error, :not_enough_money} = ExBanking.send(username, receiver, 400, "USD")
    end

    test "it fails when the sender does not exists" do
      assert {:error, :sender_does_not_exist} ==
               ExBanking.send("non_existent", "non_existent", 400, "USD")
    end

    test "it fails when the receiver does not exists", %{username: username} do
      assert {:error, :receiver_does_not_exist} ==
               ExBanking.send(username, "non_existent", 400, "USD")
    end

    test "it fails if the sender make too many requests in a short period of time", %{
      username: username
    } do
      receiver = random_name()
      ExBanking.create_user(receiver)

      execute_async(11, :send, [username, receiver, 100, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_sender})
      |> assert
    end

    test "it fails when the user makes many requests and receive transactions in a short period of time",
         %{username: username} do
      receiver = random_name()
      ExBanking.create_user(receiver)

      execute_async(2, :deposit, [receiver, 100, "USD"])

      execute_async(9, :send, [username, receiver, 1.456, "USD"])
      |> Task.await_many()
      |> Enum.member?({:error, :too_many_requests_to_receiver})
      |> assert
    end
  end

  describe "concurrency and integrity" do
    test "after many concurrent transactions the account balances shoud be correct",
         %{username: username} do
      ExBanking.deposit(username, 1000, "USD")
      receiver = random_user()
      ExBanking.deposit(receiver, 1000, "USD")
      ExBanking.deposit(receiver, 500, "ARS")

      t1 = execute_async(3, :deposit, [username, 100, "USD"])
      t2 = execute_async(3, :withdraw, [username, 100, "USD"])
      t3 = execute_async(3, :send, [username, receiver, 100, "USD"])

      Task.await_many(t1 ++ t2 ++ t3)

      assert {:ok, %Account{balance: 700}} = Accounts.get_by_currency(username, "USD")
      assert {:ok, %Account{balance: 1300}} = Accounts.get_by_currency(receiver, "USD")
      assert {:ok, %Account{balance: 500}} = Accounts.get_by_currency(receiver, "ARS")
    end

    test "the users should not block each other" do
      t1 = execute_async(9, :deposit, [random_user(), 100, "USD"])
      t2 = execute_async(9, :deposit, [random_user(), 100, "USD"])
      t3 = execute_async(9, :deposit, [random_user(), 100, "USD"])

      Task.await_many(t1)
      |> Enum.member?({:error, :too_many_requests_to_sender})
      |> refute

      Task.await_many(t2)
      |> Enum.member?({:error, :too_many_requests_to_sender})
      |> refute

      Task.await_many(t3)
      |> Enum.member?({:error, :too_many_requests_to_sender})
      |> refute
    end
  end

  defp random_name() do
    for _ <- 1..10, into: "", do: <<Enum.random('0123456789abcdef')>>
  end

  defp random_user() do
    username = random_name()
    ExBanking.create_user(username)
    username
  end

  defp execute_async(n, fun, arity) do
    for _ <- 1..n, reduce: [] do
      tasks -> [Task.async(ExBanking, fun, arity) | tasks]
    end
  end
end
