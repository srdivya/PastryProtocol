defmodule PROJECT3 do
  def main(args) do
    Pastry.start_link(Enum.at(args, 0), Enum.at(args, 1))
    :timer.sleep(100000)
  end
end
