import ../widget, ../render
from ../config import metrics, theme
from ../atlas import width
from ../../builder import widget

type
  VeAlign* = enum # Vertical
    veTop, veMiddle, veBottom
  HoAlign* = enum # Horizontal
    hoLeft, hoMiddle, hoRight
  
widget GUILabel:
  attributes:
    text: string
    # Align of Text
    v_align: VeAlign
    h_align: HoAlign
    # Cache of Position
    [cx, cy]: int32

  new label(text: string, ho: HoAlign, ve: VeAlign):
    # Set New Text
    result.text = text
    # Set Alignment
    result.h_align = ho
    result.v_align = ve
    # Set Size Hints
    result.minimum(text.width, 
      metrics.fontSize - metrics.descender)

  method layout =
    block: # X Position Align
      let 
        x = self.rect.x
        w = self.rect.w
        # Text Width
        tw = width(self.text)
      self.cx = 
        case self.h_align
        of hoLeft: x    
        of hoMiddle: 
          x + (w - tw) shr 1
        of hoRight: 
          x + w - tw
    block: # Y Position Align
      let
        y = self.rect.y
        h = self.rect.h
        # Text Height
        base = metrics.baseline
        asc = metrics.ascender
        des = metrics.descender
      self.cy =
        case self.v_align
        of veTop: y
        of veMiddle:
          y + (h - base) shr 1
        of veBottom:
          y + h - asc - des

  method draw(ctx: ptr CTXRender) =
    ctx.color(theme.text)
    # Draw Text Using Cache
    ctx.text(self.cx, self.cy, 
      rect(self.rect), self.text)
