import nogui/libs/png

proc cbStatus(data: pointer, rows, i: int32) =
  stdout.write "\rpng progress: "
  stdout.write int32(i / rows * 100)
  stdout.write "% - "
  stdout.write i
  stdout.write '/'
  stdout.write rows
  # Flush Write
  stdout.flushFile()
  if rows == i:
    stdout.write("\n")

proc main() =
  let pngRead = createReadPNG("pack/libs/test.png")
  pngRead.report.status = cbStatus
  if pngRead.readRGBA():
    echo "readed RGBA"
    block write_rgba:
      let pngWrite = createWritePNG("out_rgba.png", pngRead.w, pngRead.h)
      pngWrite.report.status = cbStatus
      copyMem(pngWrite.buffer, pngRead.buffer,
        pngRead.w * pngRead.h * 4)
      # Write RGBA Image
      discard pngWrite.writeRGBA()
      pngWrite.close()
      echo "writed RGBA"
    block write_rgb:
      let pngWrite = createWritePNG("out_rgb.png", pngRead.w, pngRead.h)
      pngWrite.report.status = cbStatus
      copyMem(pngWrite.buffer, pngRead.buffer,
        pngRead.w * pngRead.h * 4)
      # Write RGB Image
      discard pngWrite.writeRGB()
      discard pngWrite.writeRGB()
      pngWrite.close()
      echo "writed RGB"
  # Close Read File
  pngRead.close()

when isMainModule:
  main()
