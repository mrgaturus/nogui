from nogui/builder import controller, widget
import nogui/ux/widgets/menu

widget UXHelloWord:
  attributes:
    [a, b]: int

widget UXHelloWord2:
  attributes:
    [a, b]: int

template myPragma {.pragma.}

controller Hello:
  attributes:
    z: int
    {.public, bitsize: 8, myPragma.}: 
      [a, b, c]: int
    {.public.}: 
      [e, f]: int
    {.public.}: 
      [zz, aa]: int

  callback ex:
    discard

echo UXMenuBar.type