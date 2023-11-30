import gleam/io
import maze

pub fn main() {
  maze.generate(20)
  |> maze.to_string
  |> io.println
}
