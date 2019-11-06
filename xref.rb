myprogram = ARGV[0]

### PARSE LLVM-DWARFDUMP
llvmOut, llvmIO = IO.pipe
fork do
  res = system("llvm-dwarfdump --debug-line #{myprogram}", out: llvmIO, err: :out)
end 

llvmIO.close

debug_matcher = /^0x0000000000([0-9a-z]{6})\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([a-z]+.*)$.*/
file_name_matcher = /^(file_names)+(\[)\s+([0-9].*)+(\]:)\n +(name:)\s+("[a-z].*)$/\

addr_to_sourceline = {}
#addr_to_sourceline["123"]="null"
#puts addr_to_sourceline["123"]

llvmOut.each{ |l|
  if debug_matcher.match(l) then
    assembly_addr = Regexp.last_match(1)
    sourceline_num = Regexp.last_match(2).to_i
    file_number = Regexp.last_match(3).to_i
    puts IO.readlines("main.c")[1]
    addr_to_sourceline[assembly_addr] = sourceline_num
  end
}

#puts addr_to_sourceline["401106"]


###### PARSE OBJDUMP 
objdumpOut, objdumpIO = IO.pipe
fork do
  res = system("objdump -d #{myprogram}", out: objdumpIO, err: :out)
end

objdumpIO.close

objdump_addr_matcher = /^(\s*)+([0-9]*)/

objdumpOut.each{ |l|
  if objdump_addr_matcher.match(l) then
    puts Regexp.last_match(2)
  end
}

