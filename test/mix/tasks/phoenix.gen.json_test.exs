Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupJSONController do
end

defmodule Phoenix.DupJSONView do
end

defmodule Mix.Tasks.Phoenix.Gen.JsonTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates json resource" do
    in_tmp "generates json resource", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["user", "users", "name", "age:integer", "height:decimal",
                                      "nicks:array:text", "famous:boolean", "born_at:datetime",
                                      "secret:uuid", "first_login:date", "alarm:time"]

      assert_file "web/models/user.ex"
      assert_file "test/models/user_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      assert_file "web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Repo.get!"
      end

      assert_file "web/views/user_view.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserView do"
        assert file =~ "use Phoenix.Web, :view"
        assert file =~ "id: user.id"
        assert file =~ "name: user.name"
      end

      assert_file "test/controllers/user_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.UserControllerTest"
        assert file =~ "use Phoenix.ConnCase"
        assert file =~ ~S|@valid_params %{"age" => 42|
        assert file =~ ~S|@expected_attrs %{age: 42|
        assert file =~ ~S|@invalid_params %{}|

        assert file =~ ~S|test "lists all entries on index"|
        assert file =~ ~S|conn = get conn, user_path(conn, :index)|

        assert file =~ ~S|test "creates and renders resource when data is valid"|
        assert file =~ ~S|conn = post conn, user_path(conn, :create), user: @valid_params|
        assert file =~ ~r/creates.*when data is valid.*?assert Repo\.get_by\(User, @expected_attrs\).*?end/s

        assert file =~ ~S|test "does not create resource and renders errors when data is invalid"|
        assert file =~ ~S|conn = post conn, user_path(conn, :create), user: @invalid_params|

        assert file =~ ~S|test "shows chosen resource"|
        assert file =~ ~S|user = Repo.insert! %User{}|

        assert file =~ ~S|test "updates and renders chosen resource when data is valid"|
        assert file =~ ~S|conn = put conn, user_path(conn, :update, user), user: @valid_params|
        assert file =~ ~r/updates.*when data is valid.*?assert Repo\.get_by\(User, @expected_attrs\).*?end/s

        assert file =~ ~S|test "does not update chosen resource and renders errors when data is invalid"|
        assert file =~ ~S|conn = put conn, user_path(conn, :update, user), user: @invalid_params|

        assert file =~ ~S|test "deletes chosen resource"|
        assert file =~ ~S|conn = delete conn, user_path(conn, :delete, user)|
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "generates nested resource" do
    in_tmp "generates nested resource", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["Admin.User", "users", "name:string"]

      assert_file "web/models/admin/user.ex"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      assert_file "web/controllers/admin/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.UserController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Repo.get!"
      end

      assert_file "web/views/admin/user_view.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.UserView do"
        assert file =~ "use Phoenix.Web, :view"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/admin/users", Admin.UserController)
    end
  end

  test "generates json resource without model" do
    in_tmp "generates json resource without model", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["API.V1.User", "users", "--no-model", "name:string"]

      refute File.exists? "web/models/api/v1/user.ex"
      assert [] = Path.wildcard("priv/repo/migrations/*_create_api_v1_user.exs")

      assert_file "web/controllers/api/v1/user_controller.ex"
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["Admin.User", "name:string", "foo:string"]
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["DupJSON", "dupjsons"]
    end
  end
end
