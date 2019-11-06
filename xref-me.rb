#!/usr/bin/env ruby
require 'cgi'

# execute gcc to compile the code into out
myprogram = ARGV[0]

# store the info for each line in source code
# for every line of Assembly code, it has the attributes 
# codeLine => [line_content, jmp_addr/calling_addr, func]
# if no jmp_addr/calling_addr or func, put "nil".

class CodeLine 
    attr_accessor :address, :line, :jmp_addr, :func
    def initialize(addr, l, ad = nil, f = nil)
        self.address = addr
        self.line = l
        self.jmp_addr = ad
        self.func = f
    end
end

# this class store Assembly codes by functions, for each functions, 
# this class will store the first_addr of the function, name, subroutine
# and mapping functions to map each line of assembly code. 

class FuncAssembly
    @first_line
    @name
    attr_accessor :assembly, :first_addr
    def initialize(name, line)
        @name = name
        @assembly = Array.new
        @first_line = line;
        @first_addr = line.split(' ')[0][10..16]
    end
    def show_name
        puts @name
    end
    def get_name
        @name
    end
    def show_lines
        @assembly.each { |code|
            print code.line
        }
    end
    def show_addrs
        @assembly.each { |code|
            puts code.address
        }
    end
end

# This class is to store the information from dwarfdump and cross match 
# with the assembly code. 
# :source_map is use to store the information from dwarfdump
# the map key is [addr] => [line_num, col_num_num, some_info]
# :codes is the actual sourse code map by [line_num] => code_text
# :assembly_map is mapping each aseembly addr with correspoding code_line, 
# and assembly code.
# Information stores in assembly map is like 
# [addr] ==> [line_num1, line_num2, ... , [assembly_code, jmp_addr, func_name]]
#  rest of attributes are used for easy to index assembly code with sourse code.
class CodeMap
    # @lines [line_num] => [addr1, addr2, ...]
    attr_accessor :source_map, :path, :lines, :codes, :assembly_map, :min, :fname
    @max
    @total_num_lines
    def initialize(path, fname, addr, line_num, col_num, sig)
        @min = line_num
        @max = line_num
        @path = path
        @fname = fname
        @lines = {}
        @lines[line_num] = []
        @lines[line_num] << addr
        @source_map = {}
        @source_map[addr] = [line_num, col_num, sig]
    end
    def add_addr(line_num, addr)
        @lines[line_num] = [] if @lines[line_num].nil?
        @lines[line_num] << addr 
        @max = line_num if (@max < line_num)
        @min = line_num if (@min > line_num)
    end
    # this function is used to include all the code that not index to a specific 
    # assembly code, I will just include them into previous assembly code.
    def construct
        @total_num_lines = File.readlines(@path).size
        tmp = {}
        prev = ''
        (@min..@total_num_lines).each { |i|
            if i > @max then
                tmp[i] = @lines[@max]
            else
                if !lines[i].nil? then
                    tmp[i] = lines[i]
                    prev = lines[i]
                else 
                    tmp[i] = prev
                end
            end
        }
        @lines = tmp
    end
    # function for read lines in file
    def read_file
        @codes = [@path]
        File.open(@path).each { |l|
            @codes << l
        }
    end
    # we want assembly-centric, so to convert line-index to assembly-index.
    def match_assembly
        @assembly_map = {}
        lines.each { |line_num, assems|
            assems.each { |assem|
                if @assembly_map[assem].nil? then
                    @assembly_map[assem] = [line_num]
                else 
                    @assembly_map[assem] << line_num
                end
            }
            
        }
    end
    # for each assembly address, add the assembly content for generate html.
    def add_func(total_assembly)
        addrs = [];
        assembly_map.each_key { |addr|
            if !total_assembly[addr].nil? then
                addrs << addr
            end
        }
        addrs.each { |addr|
            total_assembly[addr].each { |k, v|
                if assembly_map[k].nil? then
                    assembly_map[k] = [v]
                else
                    assembly_map[k] << v 
                end
            }
        }
    end
end


######################################################################
#            This sections is to run objdump from kernel             # 
######################################################################
# read lines from objdump
obj_r, obj_io = IO.pipe
fork do
  system("objdump -d #{myprogram}", out: obj_io, err: :out)
end
obj_io.close

# regex for matching purposes.
# This is to match the head line of each objdump function.
objdump_head_match = /[0-9a-f]{16}.*\<(\p{Alnum}+?[\p{Alnum}_-]+)\>\:/
# match empty line
objdump_empty_line = /^[[:space:]]*$/
# match function call
objdump_func_call  = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s){5}(\s|callq)*([0-9a-f]{6}).*\<(\p{Alnum}+?[\p{Alnum}_]+)\>.*/
# match jmp instructions
objdump_loc_jump = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s){2,}[\s]*j[a-z]*\s*([0-9a-f]{6}).*\<(\p{Alnum}+?\S+)\>.*\n/
# match regular assembly code
objdump_asse_code  = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s)+.*/

######################################################################
#   This sections is to obtains the information from objdump         # 
######################################################################

# store the FuncAssembly class
objdump_funs = []
curr = nil
ifAdd = false

# start to match the content in objdump
obj_r.each_line { |l| 
    # to match head line such as: 00000000004007d0 <main>:
    if objdump_head_match.match(l) then
        # grep the function head line
        curr =  FuncAssembly.new(Regexp.last_match(1), l)
        objdump_funs << curr;
        ifAdd = true;
        # stop add sequential lines if meet a blank line.
    elsif objdump_empty_line.match(l) then
        ifAdd = false
    else
        # match function call but not internal function call e.g. start with "_"
        if ifAdd && objdump_func_call.match(l) then
            curr.assembly << CodeLine.new(Regexp.last_match(1), 
                    l, Regexp.last_match(4), Regexp.last_match(5))
        elsif ifAdd && objdump_loc_jump.match(l) && ifAdd then 
            curr.assembly << CodeLine.new(Regexp.last_match(1), 
                                    l, Regexp.last_match(3))
        elsif ifAdd && objdump_asse_code.match(l) then
            curr.assembly << CodeLine.new(Regexp.last_match(1), l)
        end
    end
}

######################################################################
#         Actual run dwarfdump and get inforamtions from it          #
######################################################################

dwarf_r, dwarf_io = IO.pipe
fork do
  res = system("llvm-dwarfdump --debug-line #{myprogram}", out: dwarf_io, err: :out)
end

dwarf_io.close

######################################################################
#   This sections is to obtains the information from dwarfdump       # 
######################################################################

# match dwarfdump debuger line
debug_matcher = /^0x00000000([0-9a-f]{8})\s+([0-9]{1,})\s+([0-9]{1,})\s+([0-9]{1,})\s+([0-9]{1,})\s+([0-9]{1,})\s+([a-z]+.*)$/
# match uri
uri_matcher = /^(.*)uri\:[\s]+\"(.+)\".*$/
# catch the file_name
file_name_matcher = /^\/(.+\/)*(.+)\.(.+)$/

# dwarf_output key: file_path, value: dwarf_debug_info[]
dwarf_output = {}
curr = nil
dwarf_r.each { |l|
    # for debug purpose.
    # puts l
    # match the debug_line in dwarfdump, so that we will start to read info.
    # match [addr, line_num, col_num_num, extra_info];
    if debug_matcher.match(l) then
        addr = Regexp.last_match(1)
        line_num = Regexp.last_match(2).to_i
        col_num = Regexp.last_match(3).to_i
        info = Regexp.last_match(4)
        if (uri_matcher.match(info)) then
            sig = Regexp.last_match(1).strip().split(' ')
            path = Regexp.last_match(2)
            file_name_matcher.match(path)
            # catch file_name for multi_page_identification 
            fname = "#{Regexp.last_match(2)}.#{Regexp.last_match(3)}"
            p fname
            if dwarf_output[path].nil? then
                curr = CodeMap.new(path, fname, addr, line_num, col_num, sig)
                dwarf_output[path] = curr
            else
                curr = dwarf_output[path]
            end
        else 
            sig = info.strip().split(' ')
            # add addr to lines[line_num] => [addrs]
            curr.add_addr(line_num, addr)
            # addr cross map line_num.
            curr.source_map[addr] = [line_num, col_num, sig]
        end
    end
}

puts "######################################################################"
puts "        THIS BELOW IS DWARF_CODE_LINE_DEBUG_INFO"
puts "######################################################################"

dwarf_output.each { |path, source|
    p path
    source.source_map.each { |pair|
        p pair
    }
}

# delete the path to public stdlib.
own_code_addr = {}
lib_path = ".*/include/.*"

dwarf_output.each { |path, source|
    if !path.match(lib_path) then
        source.construct
        source.lines.each { |key, lines|
            lines.sort
        }
        source.source_map.each_key { |addr| 
            own_code_addr[addr] = true
        }
        source.read_file
        puts source.lines
        puts source.codes
    else 
        dwarf_output.delete(path)
    end
}

# After extracted useful information for objdump, build an assembly code 
# map to map each assembly code by addr.
# and also find the addr of main function.
p own_code_addr
delete_indexes = []
objdump_funs.each_with_index { |func, index|
    p [func.first_addr, func.get_name]
    p own_code_addr[func.first_addr]
    # if it is not actual useful function assembly code 
    delete_indexes << index if own_code_addr[func.first_addr].nil?
}

# delete the function that are not appeal in dwarfdump
# so only keep the assembly blocks are related to source codes, not stdlib.
delete_indexes.reverse.each { |index|
    objdump_funs.delete_at(index)
}

# debug purposes, print out the result after deletion.
objdump_funs.each { |func|
    p [func.first_addr, func.get_name]
}

puts "######################################################################"
puts "          THIS BELOW IS ASSEM_EXTRACT_DEBUG_INFO"
puts "######################################################################"
main_func_adrr = ""
total_assembly = {}
objdump_funs.each { |func|
    # debug purpose 
    func.show_name
    func.show_lines
    # actual useful code 
    main_func_adrr = func.first_addr if func.get_name == "main"
    total_assembly[func.first_addr] = {}
    func.assembly.each { |l|
        total_assembly[func.first_addr][l.address] = [l.line, l.jmp_addr, l.func]
    }
}

puts "######################################################################"
puts "                THIS BELOW IS FUNC_ASSEM_DEBUG_INFO"
puts "######################################################################"
# dubug purpose
total_assembly.each { |first_addr, func_assem|
    p first_addr
    func_assem.each { |addr_and_info|
        p addr_and_info
    }
}

puts "######################################################################"
puts "        THIS BELOW IS DWARF_ASSEMBLY_MATCH_DEBUG_INFO"
puts "######################################################################"

dwarf_output.each { |path, code_map|
    code_map.match_assembly
    code_map.add_func(total_assembly)
    code_map.assembly_map.each { |info|
        p info
    }
}

# This code below is generate HTML
# all_code is a list to generate the code-side;
# all_asse is a list to generate the assembly-side;
# href is for link-reference. Here, I used the assembly-address as link-name.
# check_line is served as a hashSet to check if this line is record previously,
# then, I will only add the first line instead of all the lines co-index with 
# that assembly. This is useful to instead of print out all the loop content,
# I will only print out the loop counter.

all_code = {}
all_asse = {}
addr_file_map = {}
href = {}
check_line = {}

# Dwar_output is a filePath-index map.
# so it will mapping though all the code files.
dwarf_output.each { |path, code_map|
    # assembly text and code_text are just the addtional text to print out 
    # related assembly-lines and code_lines for each file with line number,
    # this is used for debug purpose. 
    assembly_text = ''
    code_text = ''
    fname = code_map.fname
    # classify each line&assembly with fname
    all_code[fname] = []
    all_asse[fname] = []
    href_index = 0
    check_index = 0
    check_line[fname] = {}
    # the lead_cnt is used to record which line_cnt is larger, so it will 
    # if any assembly_line_cnt is small, it will keep add empty line, same 
    # as source_code_lines. To keep them line-side-by-side-match.
    lead_cnt = 1
    asse_cnt = 1
    code_cnt = 1
    lines_set = {}
    # if there is any addtional source codes at beginning are not related to
    # any assembly code, I will just print them ahead.
    while code_cnt < code_map.min
        code_text += "[#{code_cnt}, X]\t#{code_map.codes[code_cnt]}"
        all_code[code_map.fname] << "[#{code_cnt}, X]\t#{code_map.codes[code_cnt]}".chop
        code_cnt += 1
        check_index += 1
    end
    lead_cnt = lead_cnt < code_cnt ? code_cnt : lead_cnt
    code_map.assembly_map.keys.sort.each { |addr|
        addr_file_map[addr] = fname
        curr_cnt = lead_cnt
        code_map.assembly_map[addr].each { |i|
            # If the elemenet is integer, which means it is line_number, 
            # so keep adding lines into all_code list.
            if i.class == Integer then
                # first, keep line_num match. fill with empty lines.
                while code_cnt < curr_cnt 
                    code_text += "[#{code_cnt}, X]\t\n"
                    all_code[fname] << "[#{code_cnt}, X]"
                    code_cnt += 1
                    check_index += 1
                end
                # add corresponding line.
                code_text += "[#{code_cnt}, #{i}]\t#{code_map.codes[i]}"
                all_code[fname] << "[#{code_cnt}, #{i}]\t#{code_map.codes[i]}".chop
                # if this line is written before, the next line in this 
                # address don't need to write again.
                # I just need a loop counter line.
                if lines_set.key?(i) then
                    check_line[fname][check_index] = true
                end
                # set the lead_cnt to the larger one between code and assembly.
                lines_set[i] = true
                code_cnt += 1
                check_index += 1
                lead_cnt = lead_cnt < code_cnt ? code_cnt : lead_cnt
            # this means this element is content with assembly.
            elsif i.class != Integer then
                # fill with empty lines to match the code_line_num.
                while asse_cnt < curr_cnt
                    assembly_text += "[#{asse_cnt}]\t\n"
                    all_asse[fname] << ""
                    asse_cnt += 1
                    href_index += 1
                end
                # add coresponding line
                assembly_text += "[#{asse_cnt}]\t#{i[0]}"
                all_asse[fname] << "#{i[0]}".chop
                if (!i[1].nil?) then
                    href["#{code_map.fname}, #{href_index}"] = i[1]
                    href[i[1]] = true
                end
                # set the lead_cnt to the larger one between code and assembly.
                asse_cnt += 1
                href_index += 1
                lead_cnt = lead_cnt < asse_cnt ? asse_cnt : lead_cnt
            end
        }
    }
    # fill with empty line to match the end file.
    while code_cnt < lead_cnt 
        code_text += "[#{code_cnt}, X]\t\n"
        all_code[fname] << "[#{code_cnt}, X]"
        code_cnt += 1
        check_index += 1
    end
    while asse_cnt < lead_cnt 
        assembly_text += "[#{asse_cnt}]\t\n"
        all_asse[fname] << ""
        href_index += 1
        asse_cnt += 1
    end
    puts "######################################################################"
    puts "        THIS ASSEMBLY CODE CONSTRUCT FOR \"#{fname}\""
    puts "######################################################################"
    print assembly_text
    puts "######################################################################"
    puts "        THIS SOURCE CODE CONSTRUCT FOR \"#{fname}\""
    puts "######################################################################"
    print code_text
}

puts "######################################################################"
puts "                  THIS DEBUG INFO FOR HREF_LINK"
puts "######################################################################"
p href
# The rest of code is just make HTML text and write into a file.

system("mkdir sub") if !Dir.exist?("./sub")
all_code.each { |fname, content|

html_text = "<!DOCTYPE html>
<html>
<head>
    <title>CSC 454 #{fname}</title>
    <style type=\"text/css\">
        * { 
            font-family: monospace; 
            line-height: 1.5em;
        }
        table {
            width: 100%;
        }
        td
        {
            padding: 8px;
            vertical-align: bottom;
            width: 50%;
        }
        th
        {
            border: 1px solid black;
        }
        .grey {
            col_numor: #888
        }
    </style>
</head>
<body>
    <table>
"
    # for each file, I am write down the source code lines and assembly line 
    # line by line 
    content.each_index { |i|
        # This the source code part.
        html_text += "      <tr>\n"
        # using check_line to check if this line_num is already appear in
        # the previous content, if so we grey_col_numor this line.
        if check_line[fname][i] then
            html_text += "          <td class=\"grey\">\n"
        else
            html_text += "          <td>\n"
        end
        # for the source and assembly line, in addtion to escape some HTML 
        # character, I also need to escape empty space.
        html_text += "              " + CGI.escapeHTML(all_code[fname][i]).gsub(/ /, "&nbsp;") + "<br>\n"
        html_text += "          </td>\n"
        html_text += "          <td>\n"
        addr = ""
        if (all_asse[fname][i].length > 1) then
            addr = all_asse[fname][i].split(":")[0].strip
        end
        # This is the assembly code part
        href_index = "#{fname}, #{i}"
        # if this addr is related to a function call or a jump, we need to 
        # create a hyperlink.
        if href[addr] || addr == main_func_adrr then
            html_text += "          <a name=\""+ addr +"\">\n"
            html_text += "              " + CGI.escapeHTML(all_asse[fname][i]).gsub(/ /, "&nbsp;") + "<br>\n"
            html_text += "          </td>\n"
        # if this assembly code is related to a hyperlink reference.
        # make a href.
        elsif !href[href_index].nil? then
            html_text += "          <a href=\"./#{addr_file_map[href[href_index]]}.html##{href[href_index]}\">"
            html_text += "              " + CGI.escapeHTML(all_asse[fname][i]).gsub(/ /, "&nbsp;") + "</a> <br>\n"
            html_text += "          </td>\n"
        # otherwise just assemble them as a regualar table col_num.
        else 
            html_text += "              " + CGI.escapeHTML(all_asse[fname][i]).gsub(/ /, "&nbsp;") + "<br>\n"
            html_text += "          </td>\n"
        end
        html_text += "      </tr>\n"
    }

html_text += "
    </table>
</body>
</html>
"
    # write down each file into the "sub" directory.
    File.write("./sub/#{fname}.html", html_text)
}


# this is section to generate the index HTML file for the "sub" directory.
html_index = "<!DOCTYPE html>
<html>
<head>
    <title>CSC 454 HW04 INDEX</title>
    <style type=\"text/css\">

        * { 
            font-family: monospace; 
            line-height: 1.5em;
        }

        table {
            width: 100%;
        }

        td
        {
            padding: 8px;
            vertical-align: bottom;
            width: 50%;
        }

        th
        {
            border: 1px solid black;
        }

    </style>
</head>
<body>
    <table>
      <tr>
          <td>
          <a href=\"./sub/#{addr_file_map[main_func_adrr]}.html##{main_func_adrr}\">main</a> <br>
          </td>
      </tr>" 
all_code.each_key { |fname|
html_index +=
"      <tr>
          <td>
          <a href=\"./sub/#{fname}.html\">#{fname}</a> <br>
          </td>
      </tr>"   


}
html_index += "
    </table>
</body>
</html>
"

File.write('./index.html', html_index)
