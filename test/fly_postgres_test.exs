defmodule Fly.PostgresTest do
  # uses async false because we mess with the DATABASE_ENV value
  use ExUnit.Case, async: false

  doctest Fly.Postgres

  @url_dns "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5432/some_app"
  @url_base "postgres://some-user:some-pass@my-app-db.internal:5432/some_app"

  setup do
    System.put_env([{"FLY_REGION", "abc"}, {"PRIMARY_REGION", "xyz"}, {"DATABASE_URL", @url_dns}])

    %{}
  end

  describe "rewrite_database_url/1" do
    test "returns config unchanged when in primary region and includes DNS helper parts" do
      System.put_env([{"FLY_REGION", "xyz"}])
      config = [stuff: "THINGS", url: System.get_env("DATABASE_URL")]
      assert config == Fly.Postgres.rewrite_database_url(config)
    end

    test "adds DNS helper parts when missing from URL" do
      config = [stuff: "THINGS", url: @url_base]
      System.put_env([{"FLY_REGION", "xyz"}, {"DATABASE_URL", @url_base}])
      config = Fly.Postgres.rewrite_database_url(config)
      assert Keyword.get(config, :url) |> String.contains?("top2.nearest.of.")
    end

    test "changes port when not in primary region" do
      config = [stuff: "THINGS", url: System.get_env("DATABASE_URL")]
      # NOTE: Only the port number changed
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5433/some_app"
      updated = Fly.Postgres.rewrite_database_url(config)
      assert expected == Keyword.get(updated, :url)
      # other things are altered
      assert Keyword.get(updated, :stuff) == Keyword.get(config, :stuff)
    end

    test "changes port and adds DNS helpers if missing when not in primary region" do
      config = [stuff: "THINGS", url: @url_base]
      # NOTE: Port number changed and DNS parts added to host
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5433/some_app"
      updated = Fly.Postgres.rewrite_database_url(config)
      assert Keyword.get(updated, :url) == expected
    end
  end

  describe "rewrite_host/1" do
    test "adds dns helpers if missing from host" do
      config = [stuff: "THINGS", url: @url_base]
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5432/some_app"
      updated = Fly.Postgres.rewrite_host(config)
      assert Keyword.get(updated, :url) == expected
    end

    test "returns unmodified if dns helpers detected" do
      config = [stuff: "THINGS", url: @url_dns]
      updated = Fly.Postgres.rewrite_host(config)
      assert Keyword.get(updated, :url) == @url_dns
    end
  end

  describe "rewrite_replica_port/1" do
    test "if running on the primary, returns unchanged" do
      System.put_env([{"FLY_REGION", "xyz"}])
      # test when includes "top2.nearest.of..."
      config = [stuff: "THINGS", url: @url_dns]
      updated = Fly.Postgres.rewrite_replica_port(config)
      # NOTE: Port number NOT changed
      assert Keyword.get(updated, :url) == @url_dns
    end

    test "if not in primary region, change port to 5433" do
      System.put_env([{"FLY_REGION", "abc"}])
      # test when includes "top2.nearest.of..."
      config = [stuff: "THINGS", url: @url_dns]
      updated = Fly.Postgres.rewrite_replica_port(config)
      # NOTE: Port number should change
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5433/some_app"
      assert Keyword.get(updated, :url) == expected
      assert @url_dns != expected
    end
  end

  describe "config_repo_url/1" do
    test "don't do anything when no :url is included" do
      config = [stuff: "THINGS", database: "my-db"]
      assert {:ok, config} == Fly.Postgres.config_repo_url(config)
    end

    test "updates url with DNS for primary" do
      System.put_env([{"FLY_REGION", "xyz"}])
      config = [stuff: "THINGS", url: @url_base]
      # NOTE: Only the port number changed
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5432/some_app"
      {:ok, updated} = Fly.Postgres.config_repo_url(config)
      assert expected == Keyword.get(updated, :url)
    end

    test "update url for replica PORT when given" do
      config = [stuff: "THINGS", url: System.get_env("DATABASE_URL")]
      # NOTE: Only the port number changed
      expected = "postgres://some-user:some-pass@top2.nearest.of.my-app-db.internal:5433/some_app"
      {:ok, updated} = Fly.Postgres.config_repo_url(config)
      assert expected == Keyword.get(updated, :url)
    end
  end
end
