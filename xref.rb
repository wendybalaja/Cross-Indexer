require 'cgi'
myprogram = ARGV[0]

### PARSE LLVM-DWARFDUMP
llvmOut, llvmIO = IO.pipe
fork do
  res = system("llvm-dwarfdump --debug-line #{myprogram}", out: llvmIO, err: :out)
end 

llvmIO.close

#matches the entire debug line in llvm-dwarfdump
debug_matcher = /^0x0000000000([0-9a-z]{6})\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([0-9]*)\s+([a-z]+.*)$.*/

#matches the file number to file name
file_name_1_matcher = /^(file_names)+(\[)\s+([0-9].*)+(\]:)$/
file_name_2_matcher = /^(\s*)+(name:\s)+\"([a-z0-9]*\.[a-z])\"$/


file_number = 0;
file_name = ""
file_number_to_name = {}
assembly_addr_to_sourceline = {}
assembly_addr_to_filename = {}
# EXTRACT INFO FROM LLVM-DWARFDMP --DEBUG-LINE OUTPUT
llvmOut.each{ |l|

  #Store file_number with file_name
  if file_name_1_matcher.match(l) then
    file_number =  Regexp.last_match(3).to_i
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
    assembly_addr_to_filename[assembly_addr] = file_name
   
    get_name = assembly_addr_to_filename[assembly_addr]
    file = File.open(get_name) 
    source_line = IO.readlines(file)[sourceline_num-1]
    assembly_addr_to_sourceline[assembly_addr] = source_line
  
    file.close
  
  end
}


#HTML_TEXT FRAMEWORK AND STYLE SHEET
html_text ="
<!DOCTYPE html>
<head>
 <title>xref for binary file</title>
 <link rel=\"stylesheet\" type= \"text/css\" href=\"https://cdn.jsdelivr.net/gh/google/code-prettify@master/loader/prettify.css\">
 <style type=\"text/css\">
   *{ font-family: monospace; }
   .grey{
    color: #faa19b
  }

   .red{
    color: #fa1f0f
  }

 </style>
</head>

<body>
 <h2>xref for binary file</h2>
 <table> 
"

###### PARSE OBJDUMP 
objdumpOut, objdumpIO = IO.pipe
fork do
  res = system("objdump -d #{myprogram}", out: objdumpIO, err: :out)
end

objdumpIO.close

# match objdump output that begins with an address 
objdump_addr_matcher = /^(\s*)+([0-9]*):+\s([0-9a-z].*)$/
previous_sourceline = ""

# loop through each output in objdump
# check if matches with any sourceline
# write to the html_text 
objdumpOut.each{ |l|
  if objdump_addr_matcher.match(l) then
    objdump_assembly_addr = Regexp.last_match(2)
    objdump_assembly_code = Regexp.last_match(3)
    html_text += "  <tr>\n"
    html_text += "  <td>\n"
    html_text += " <a name=\"#{objdump_assembly_addr}\" href=\"##{objdump_assembly_addr}\">\n"
    html_text += "        " + CGI.escapeHTML(objdump_assembly_addr).gsub(/ /,"&nbsp;")
    html_text += "  </a>\n"
    html_text += "        "+ CGI.escapeHTML(objdump_assembly_code).gsub(/ /, "&nbsp;")+"<br>\n"
    html_text += "        </td>\n"
    if assembly_addr_to_sourceline.key?(objdump_assembly_addr) then
      html_text += "  <td>\n"
      html_text += "               "+ CGI.escapeHTML(assembly_addr_to_filename[objdump_assembly_addr]).gsub(/  /, "&nbsp;")+ "<br>\n"
      if(assembly_addr_to_sourceline[objdump_assembly_addr]==previous_sourceline) then
        html_text += " <td class =\"grey\">\n"
      else
        previous_sourceline = assembly_addr_to_sourceline[objdump_assembly_addr] 
        html_text += "  <td class =\"red\">\n"
      end 
      html_text += "               "+ CGI.escapeHTML(previous_sourceline).gsub(/  /,"&nbsp;")+"<br>\n"
      
      print  assembly_addr_to_sourceline[objdump_assembly_addr]
    end
    html_text += "        </tr>\n"
  end
}
html_text += "
 </table>
</body>
</html>"

 
 File.write("./index.html",html_text)
