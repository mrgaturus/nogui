from nogui/builder import controller, widget
from nogui/core/event import GUIState

widget UXHelloWord:
  attributes:
    [a, b]: int

  callback cbTest:
    echo "hello world"

widget UXHelloWord2 of UXHelloWord:
  attributes:
    [hola, mundo]: int

  method event(state: ptr GUIState) =
    discard

controller CXTest of RootObj:
  callback cbTest:
    echo "hello world"

  callback cbTost:
    echo "hello world"

controller CXTest2 of CXTest:
  new cxprev():
    echo "hello world"

  callback cbA:
    echo "hello world"

  callback cbB:
    echo "hello world"