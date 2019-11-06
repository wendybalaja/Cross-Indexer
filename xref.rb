myprogram = ARGV[0]

### PARSE LLVM-DWARFDUMP
llvmOut, llvmIO = IO.pipe
fork do
  res = system("llvm-dwarfdump --debug-line #{myprogram}", out: llvmIO, err: :out)
end 

llvmIO.close

debug_matcher = /^0x0000000000([0-9a-z]{6})\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([a-z]+.*)$.*/
file_name_1_matcher = /^(file_names)+(\[)\s+([0-9].*)+(\]:)$/
file_name_2_matcher = /^(\s*)+(name:\s)+(.*)$/

#addr_to_sourceline = {}
#addr_to_sourceline["123"]="null"
#puts addr_to_sourceline["123"]

file_number = 0;
file_name = ""
file_number_to_name = {}
assembly_addr_to_sourceline = {}
# EXTRACT INFO FROM LLVM-DWARFDMP --DEBUG-LINE OUTPUT
llvmOut.each{ |l|

  #Store file_number with file_name
  if file_name_1_matcher.match(l) then
    file_number =  Regexp.last_match(3).to_i
   #puts file_number
  end

  if file_name_2_matcher.match(l) then
    file_name = Regexp.last_match(3);
    file_number_to_name[file_number] = file_name
  end

  #Store assembly_address with particular source_line 
  if debug_matcher.match(l) then
    assembly_addr = Regexp.last_match(1)
    sourceline_num = Regexp.last_match(2).to_i
    source_file_number = Regexp.last_match(4).to_i
    
    file_name = file_number_to_name[source_file_number]
    file = File.open("main.c") 
    #TODO:file_num,file_name pair is stored,but not working properly here 
    
    #file = File.open(file_number_to_name[source_file_number])
    source_line = IO.readlines(file)[sourceline_num-1]
    assembly_addr_to_sourceline[assembly_addr] = source_line
  
    file.close
  
  end
}


#puts file_number_to_name[1]
#puts addr_to_sourceline["401106"]


###### PARSE OBJDUMP 
objdumpOut, objdumpIO = IO.pipe
fork do
  res = system("objdump -d #{myprogram}", out: objdumpIO, err: :out)
end

objdumpIO.close

objdump_addr_matcher = /^(\s*)+([0-9]*):+\s([0-9a-z].*)$/

objdumpOut.each{ |l|
  if objdump_addr_matcher.match(l) then
    objdump_assembly_addr = Regexp.last_match(2) 
    #puts objdump_assembly_addr
    #puts assembly_addr_to_sourceline.key?("401106")
    if assembly_addr_to_sourceline.key?(objdump_assembly_addr) then
      puts "***************"
      puts assembly_addr_to_sourceline[objdump_assembly_addr]
      puts "***************"
    end
    puts l
  end
}
