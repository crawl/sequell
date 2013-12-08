class IRCColor
  COLOR_ESCAPE = "\x03"
  COLOR_RESET  = "\x0f"

  COLOR_CODES = {
    'white' => 0,
    'black' => 1,
    'blue'  => 2,
    'green' => 3,
    'red'   => 4,
    'brown' => 5,
    'magenta' => 6,
    'orange' => 7,
    'yellow' => 8,
    'lightgreen' => 9,
    'cyan' => 10,
    'lightcyan' => 11,
    'lightblue' => 12,
    'lightmagenta' => 13,
    'grey' => 14,
    'lightgrey' => 15
  }

  COLOR_NAMES = COLOR_CODES.invert

  def self.color_code?(x)
    x.index(COLOR_ESCAPE) || x.index(COLOR_RESET)
  end

  def self.reset
    COLOR_RESET
  end

  def self.color(fg, bg=nil)
    return fg if color_code?(fg)
    base = COLOR_ESCAPE + "#{color_code(fg)}"
    base += ",#{color_code(bg)}" if bg
    base
  end

  def self.color_code(x)
    COLOR_CODES[x.to_s.downcase] || x
  end

  def self.color_name(x)
    COLOR_NAMES[x]
  end
end
