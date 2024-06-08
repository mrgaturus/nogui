import json
import shutil
import os

# -------------------
# nogui Keymap Define
# -------------------

class KeymapDefine:
  def __init__(self, filename):
    # Load JSON File
    f = open(filename)
    data = json.load(f)

    # Sort Keymap List
    keys = data['keys'].items()
    keys = sorted(keys, key=lambda item: int(item[1]))
    keys = dict(keys)
    # Sort Keymap Strings
    strings = data['strings'].items()
    strings = map(lambda item: (keys[item[0]], item[1]), strings)
    strings = sorted(strings, key=lambda item: int(item[0]))
    strings = dict(strings)

    # Store Key List
    self.keys = keys
    self.strings = strings
    # Store Object List
    self.name_keys_nim = data['name_keys_nim']
    self.name_keys_c = data['name_keys_c']
    self.name_strings_type = data['name_strings_type']
    self.name_strings_const = data['name_strings_const']

  # -- Nim Code Generation --
  def generate_enum_nim(self):
    code = "type\n"
    enum = "  %s* {.size: 4, pure, importc: \"%s\".} = enum\n"
    code += enum % (self.name_keys_nim, self.name_keys_c)
    # Generate Keys
    for key, value in self.keys.items():
      code += "    %s = 0x%x\n" % (key, value)
    # Return Generated Code
    return code

  # -- C Code Generation --
  def generate_enum_c(self):
    code = "typedef enum {\n"
    # Generate Keys
    for key, value in self.keys.items():
      code += "  %s = 0x%x,\n" % (key, value)
    # Create Type Name
    code = code.rstrip(",\n")
    code += "\n} %s;\n" % self.name_keys_c
    # Return Generated Code
    return code

  def generate_strings_type(self):
    code = "typedef struct {\n"
    code += "  %s key;\n" % self.name_keys_c
    code += "  const char* value;\n"
    code += "} %s;\n" % self.name_strings_type
    # Return Generated Code
    return code

  def generate_strings_const(self):
    code = "const static %s %s[] = {\n"
    code = code % (self.name_strings_type, self.name_strings_const)
    # Generate String Constants
    for key, value in self.strings.items():
      code += "  {%s, \"%s\"},\n" % (key, value)
    # Generate End
    code = code.rstrip(",\n")
    code += "\n};"
    # Return Generated Code
    return code

# ----------------------
# nogui Keymap Overrides
# ----------------------

class KeymapOverride:
  def __init__(self, defines, filename):
    # Load JSON File
    f = open(filename)
    data = json.load(f)

    # Sort Override List
    keys = data['overrides'].items()
    keys = sorted(keys, key=lambda item: int(item[0]))
    keys = dict(keys)
    
    self.defines = defines
    # Store Override Type
    self.name_type = data['name_type']
    self.name_const = data['name_const']
    # Store Override List
    self.overrides = keys

  # -- C Code Generation --
  def generate_type(self):
    code = "typedef struct {\n"
    code += "  unsigned int key;\n"
    code += "  %s value;\n" % self.defines.name_keys_c
    code += "} %s;\n" % self.name_type
    # Return Generated Code
    return code

  def generate_table(self):
    code = "const static %s %s[] = {\n"
    code = code % (self.name_type, self.name_const)
    # Generate String Constants
    for key, value in self.overrides.items():
      code += "  {%s, %s},\n" % (key, value)
    # Generate End
    code = code.rstrip(",\n")
    code += "\n};"
    # Return Generated Code
    return code

# ---------------------------
# nogui Keymap Defines Output
# ---------------------------

def generate_defines(json, output_folder):
  keys = KeymapDefine(json)
  name = json.rstrip(".json")

  # Generate Nim Code
  with open(output_folder + ("/%s.nim" % name), 'w') as file:
    code_nim = keys.generate_enum_nim()
    file.write(code_nim)

  # Generate C Code
  with open(output_folder + ("/%s.c" % name), 'w') as file:
    file.write( keys.generate_enum_c() + "\n" )
    file.write( keys.generate_strings_type() + "\n" )
    file.write( keys.generate_strings_const() + "\n" )
  
  # Return Define Keys for Overrides
  return keys

# -----------------------------
# nogui Keymap Overrides Output
# -----------------------------

def generate_override(keys, json, output_file):
  override = KeymapOverride(keys, json)
  # Generate C Code
  with open(output_file, 'w') as file:
    file.write( override.generate_type() + "\n" )
    file.write( override.generate_table() + "\n" )

def generate_overrides(keys, folder, output_folder):
  # Generate Overrides
  for file in os.listdir(folder):
    json = os.path.join(folder, file)
    # Check if is actually a file
    if os.path.isfile(json):
      output = output_folder + "/" + json.rstrip(".json") + ".c"
      generate_override(keys, json, output)

# -----------------
# nogui Keymap Main
# -----------------

def create_output_folder(folder):
  # Remove a directory if it exists
  if os.path.exists(folder):
    shutil.rmtree(folder)
  # Create a new directory
  os.mkdir(folder)
  os.mkdir(folder + "/native")

def main():
  output = "output"
  create_output_folder(output)
  # Generate Keymap Definition
  keys = generate_defines("keymap.json", output)
  generate_overrides(keys, "native", output)

if __name__ == "__main__":
  main()
