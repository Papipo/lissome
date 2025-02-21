defmodule LissomeTest do
  use ExUnit.Case
  doctest Lissome

  test "can call Gleam library" do
    assert :gleam@string.length("Hello") == 5
  end
end
