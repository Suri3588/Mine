import io
import os
import sys
import json
import jinja2

def getLineEndings(the_filepath):
    f = open(the_filepath, 'U')
    f.readline()
    return f.newlines

def getRealFileLocation(the_filepath):
    __location__ = os.path.realpath(os.path.join(os.getcwd(), os.path.dirname(the_filepath)))
    the_full_file_location = os.path.join(__location__, the_filepath)
    
    return the_full_file_location

def getFileName(the_filepath):
    path, filename_w_j2 = os.path.split(getRealFileLocation(the_filepath))
    
    filename_split = filename_w_j2.rsplit(".j2")
    
    # didn't find j2 where it was expected which means this is invalid input
    if len(filename_split) != 2:
        raise ValueError('A file was supplied to this function without a j2 extension. This is an error as this function expects this extension convention: myfile.txt.j2 which ultimates creates a file myfile.txt')
        
    # filename_split will be of the form ['myfile.txt', ''] when given a file of the form myfile.txt.j2
    return filename_split[0]

def renderJ2File(template_filepath, json_vars_filepath):
    json_file = open(getRealFileLocation(json_vars_filepath), "r")    
    jsonVars = json.load(json_file)
    
    # Todo: add other ansible reserved keywords/vars
    # HACK
    # allow for reserved variables {{ item }}, {{ inventory_hostname }} to be used in ansible playbooks
    # by adding a var of the form {{ XXX }} to the expansion, {{ XXX }} in playbooks are evaluated to {{ XXX }}
    jsonVars["item"] = "{{ item }}"
    jsonVars["inventory_hostname"] = "{{ inventory_hostname }}"
    jsonVars["ansible_default_ipv4_address"] = "{{ ansible_default_ipv4.address }}"
    jsonVars["command_stdout"] = "{{ command.stdout }}"
    
    path, filename = os.path.split(template_filepath)
    
    # ensure that macro expansion lines do not get rendered in output
    # see: https://stackoverflow.com/questions/35775207/remove-unnecessary-whitespace-from-jinja-rendered-template
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(path or './'),trim_blocks=True,lstrip_blocks=True,undefined=jinja2.StrictUndefined)
    return env.get_template(filename).render(jsonVars)

if __name__ == "__main__":
    template_filepath = sys.argv[1]
    json_vars_filepath = sys.argv[2]
    
    renderedData = renderJ2File(template_filepath, json_vars_filepath)  
    
    filenameRealLocation = getRealFileLocation(template_filepath)
    filename = filenameRealLocation.rsplit(".j2")[0]
    newlineChars = getLineEndings(filenameRealLocation)

    # preserve the line endings from the template in the output file
    renderedFile = io.open(filename, "w", newline=newlineChars)
    
    renderedFile.write(renderedData)
    renderedFile.close()
