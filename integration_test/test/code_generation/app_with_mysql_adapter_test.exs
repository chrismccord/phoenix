defmodule Phoenix.Integration.CodeGeneration.AppWithMySqlAdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "new with defaults" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_mysql_adapter", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "mysql_app", [
            "--database",
            "mysql"
          ])

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql"])

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.html" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_mysql_adapter", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "phx_blog", [
            "--database",
            "mysql"
          ])

        mix_run!(~w(phx.gen.html Blog Post posts title:unique body:string), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql"])

        mix_run!(~w(phx.gen.html Blog Post posts title body:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMysqlAppWeb do
              pipe_through [:browser]

              resources "/posts", PostController
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.json" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_mysql_adapter", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "phx_blog", [
            "--database",
            "mysql"
          ])

        mix_run!(~w(phx.gen.json Blog Post posts title:unique body:string), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql"])

        mix_run!(~w(phx.gen.json Blog Post posts title body:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMysqlAppWeb do
              pipe_through [:api]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.live" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_mysql_adapter", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "phx_blog", [
            "--database",
            "mysql",
            "--live"
          ])

        mix_run!(~w(phx.gen.live Blog Post posts title:unique body:string), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql", "--live"])

        mix_run!(~w(phx.gen.live Blog Post posts title body:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMysqlAppWeb do
              pipe_through [:browser]

              live "/posts", PostLive.Index, :index
              live "/posts/new", PostLive.Index, :new
              live "/posts/:id/edit", PostLive.Index, :edit

              live "/posts/:id", PostLive.Show, :show
              live "/posts/:id/show/edit", PostLive.Show, :edit
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
