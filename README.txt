*What we have in the folder: 
file1.c
file2.c
file2.h
xref.rb

*Compile instructions: 
	while in directory 
	$ gcc -g3 -o myprogram file1.c file2.c
	$ ruby xref.rb myprogram
	// A new HTML file index.html will be generated, please evaluate

*Implementation details:
	Understanding the project requirements is HARD. Learning Ruby is HARD, too. 
	We started out by constructing the data structures that will be used in the whole matching process. In this case, it will mainly be hashmaps and if/else statements 
	We decided to first filter out information we need from llvm-dwarfdump. First, we use regular expression to extract informations from the output. Then we construct hashmaps that maps [file_number, file_name], [assembly_addr, (sourceline_number,file_number)] that results in a conclusive map [assembly_addr, actual_sourceline] 
	We decided to iterate through the entire objdump output and keep printing each assembly lines while check if there's any sourceline that corrolates with particular assembly address by referring to the map we created from previous step. If there is a match, we will print the sourceline to the html. 
	After the above steps, we have a skeleton program that works with desired output. TO finalize the project, we organize the html to make it tidier, add the hyperlink to each assembly line, "greyed-out" the source line that appears more than once, support multi-file by printing out matching file_name next to the sourceline. 

*Negative aspects: 
	1)In order to make the hyperlink work, we would not be able to use the "prettify" build-in JavaScript to make the layout prettier
	2)This regular expression matching for llvm-dwarfdump and objdump will only work if the appearance of the information we require appears in particular order.

*Positive aspects: 
	1)The structure is straightforward and tidy. ALl desired information is scraped out and stored in different maps for future use. 
	2)The regular expression matching works perfectly. 
	3)The HTML file provides all the information side-by-side

*Cheers*
 
