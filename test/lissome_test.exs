defmodule LissomeTest do
  use ExUnit.Case
  doctest Lissome

  test "can call Gleam code" do
    assert :lissome.hello() == "Hello from Gleam!"
  end

  test "can call Gleam library" do
    assert :gleam@string.length("Hello") == 5
  end
end
