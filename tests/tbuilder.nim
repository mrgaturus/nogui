from nogui/builder import controller, widget

widget UXHelloWord:
  attributes:
    #[
    b: int
    [z, e, f]: int
    {.public.}:
      b: int
    {.public, value.}:
      c: int
    @public:
      d: int
    type A = object
      a: Value[int]
      b* {.cursor.}: ref int
      c {.cursor, hello.}: Value[int]
      z: int
      x*: int
    ]#
    type A = object
      e* {.cursor, hello: "Hello World".}, f {.cursor.}: int
      a, b, c: int
  type
    Hola = ref object
      a* {.bitsize: 8.}, b* {.myPragma.}: int

template myPragma {.pragma.}

controller UXHello:
  attributes:
    z: int
    {.public, bitsize: 8, myPragma.}: 
      [a, b, c]: int
    {.value.}: 
      [e, f]: int
    {.public.}: 
      [zz, aa]: int

