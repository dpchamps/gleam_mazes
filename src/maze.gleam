import gleam/iterator
import gleam/list
import gleam/result
import gleam/int

pub type Coord =
  #(Int, Int)

pub type Maze =
  List(List(Int))

pub type Frontier =
  List(Coord)

fn get_square_text(square_type: Int) -> String {
  let is_south = int.bitwise_and(square_type, direction_val(South)) == 0
  let is_east = int.bitwise_and(square_type, direction_val(East)) == 0
  let is_west = int.bitwise_and(square_type, direction_val(West)) == 0
  let is_north = int.bitwise_and(square_type, direction_val(North)) == 0
  case square_type {
    _ if is_south -> "__"
    _ if is_west -> "| "
    _ if is_east -> "  |"
    _ -> "  "
  }
}

pub fn empty(dimension: Int) -> Maze {
  iterator.iterate(
    [],
    fn(_) {
      iterator.iterate(0, fn(x) { x })
      |> iterator.take(dimension)
      |> iterator.to_list
    },
  )
  |> iterator.take(dimension)
  |> iterator.to_list
}

pub fn to_string(maze: Maze) -> String {
  list.fold(maze, "", fn(acc, row) { acc <> "--" }) <> list.fold(
    maze,
    "",
    fn(acc, row) {
      acc <> list.fold(row, "", fn(acc, el) { acc <> get_square_text(el) }) <> "\n"
    },
  ) <> list.fold(maze, "", fn(acc, row) { acc <> "--" })
}

fn at_coord(maze: Maze, coord: Coord) {
  coord.0
  |> list.at(maze, _)
  |> result.map(fn(col) {
    coord.1
    |> list.at(col, _)
  })
  |> result.flatten
}

const in_marked = 0x10

const frontier_marked = 0x20

pub type Direction {
  North
  South
  East
  West
}

fn direction_val(dir: Direction) -> Int {
  case dir {
    North -> 1
    South -> 2
    East -> 4
    West -> 8
  }
}

fn opposite_direction(dir: Direction) -> Direction {
  case dir {
    East -> West
    West -> East
    North -> South
    South -> North
  }
}

fn create_direction(from_coord: Coord, to_coord: Coord) -> Direction {
  case True {
    _ if from_coord.1 < to_coord.1 -> East
    _ if from_coord.1 > to_coord.1 -> West
    _ if from_coord.0 < to_coord.0 -> South
    _ if from_coord.0 > to_coord.0 -> North
    _ -> North
  }
}

fn is_marked(maze: Maze, coord: Coord) {
  coord
  |> at_coord(maze, _)
  |> result.map(fn(el) { int.bitwise_and(el, in_marked) != 0 })
  |> result.unwrap(False)
}

fn get_neighbors(maze: Maze, coord: Coord) -> List(#(Int, Int)) {
  let maze_len = list.length(maze)
  [
    #(coord.0 - 1, coord.1),
    #(coord.0 + 1, coord.1),
    #(coord.0, coord.1 - 1),
    #(coord.0, coord.1),
  ]
  |> list.map(fn(neighbor_coord) {
    let is_coord_marked = is_marked(maze, coord)

    case neighbor_coord {
      _ if neighbor_coord.0 < 0 || neighbor_coord.0 >= maze_len -> Error(Nil)
      _ if neighbor_coord.1 < 0 || neighbor_coord.1 >= maze_len -> Error(Nil)
      _ if is_coord_marked -> Error(Nil)
      _ -> Ok(neighbor_coord)
    }
  })
  |> list.filter_map(fn(x) { x })
}

fn update_maze_cell(maze: Maze, coord: Coord, value: Int) -> Maze {
  maze
  |> list.index_map(fn(row_idx, col) {
    col
    |> list.index_map(fn(col_idx, cell) {
      case row_idx, col_idx {
        _, _ if row_idx == coord.0 && col_idx == coord.1 ->
          int.bitwise_or(cell, value)
        _, _ -> cell
      }
    })
  })
}

fn update_frontier(
  to_update: #(Maze, Frontier),
  coord: Coord,
) -> #(Maze, Frontier) {
  let maze = to_update.0
  let frontier = to_update.1
  let maze_len = list.length(maze)
  let in_bounds =
    coord.0 >= 0 && coord.1 >= 0 && coord.0 < maze_len && coord.1 < maze_len
  let is_empty = at_coord(maze, coord) == Ok(0)
  case coord {
    _ if in_bounds && is_empty -> #(
      update_maze_cell(maze, coord, frontier_marked),
      list.append(frontier, [coord]),
    )
    _ -> #(maze, frontier)
  }
}

fn mark_cell(maze: Maze, frontier: Frontier, coord) -> #(Maze, Frontier) {
  maze
  |> update_maze_cell(coord, in_marked)
  |> fn(maze) { #(maze, frontier) }
  |> update_frontier(#(coord.0 - 1, coord.1))
  |> update_frontier(#(coord.0 + 1, coord.1))
  |> update_frontier(#(coord.0, coord.1 - 1))
  |> update_frontier(#(coord.0 - 1, coord.1 + 1))
}

fn generate_inner(state: #(Maze, Frontier)) -> #(Maze, Frontier) {
  let selected_frontier =
    state.1
    |> list.shuffle()
    |> list.first()
    |> result.unwrap(#(-1, -1))

  let selected_neighbor =
    get_neighbors(state.0, selected_frontier)
    |> list.shuffle()
    |> list.first()
    |> result.unwrap(#(-1, -1))

  let next_frontier =
    state.1
    |> list.filter(fn(el) { el != selected_frontier })

  let dir = create_direction(selected_frontier, selected_neighbor)

  let opposite_dir = opposite_direction(dir)

  let next_maze =
    update_maze_cell(state.0, selected_frontier, direction_val(dir))
    |> update_maze_cell(selected_frontier, direction_val(opposite_dir))

  let next_state = mark_cell(next_maze, next_frontier, selected_frontier)

  case list.length(state.1) {
    n if n > 0 -> generate_inner(next_state)
    _ -> next_state
  }
}

pub fn generate(dimension: Int) -> Maze {
  let initial_state =
    empty(dimension)
    |> mark_cell([], #(int.random(0, dimension), int.random(0, dimension)))

  generate_inner(initial_state).0
}
