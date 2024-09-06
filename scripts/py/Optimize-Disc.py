# Optimize-Disc.py
# Using 7z and chdman after obtaining raw disc image is a bit tedious
# Speed it up with this script

import os
import py7zr
import subprocess
import sys 

def extract_archive(archive):
    try:
        with py7zr.SevenZipFile(archive, mode='r') as archive:
            archive.extractall()
    except:
        print("Error extracting " + archive)

def search_path_for_discs(path):
    found_discs = []
    
    supported_archives = ('.7z', '.gz', '.rar', '.zip')
    supported_discs = ('.iso', '.bin', '.cue', '.gdi', '.raw', '.chd')
  
    if os.path.isdir(path):
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith((supported_discs)):
                    found_discs.append(os.path.join(root, file))
                    
    elif os.path.isfile(path):
        supported_archives = ('.7z', '.gz', '.rar', '.zip')
        if path.endswith((supported_archives)):
            with py7zr.SevenZipFile(path, mode='r') as archive:
                found_discs.extend([entry for entry in archive.getnames() if entry.endswith((supported_discs))])
        
    return found_discs

# If no arguments are provided, search current directory
if len(sys.argv) == 1:
        search_path_for_discs(os.getcwd())
        if len(search_path_for_discs(os.getcwd())) == 0:
            print("No supported disc files found in current directory")
        elif len(search_path_for_discs(os.getcwd())) > 0:
            print("Found " + str(len(search_path_for_discs(os.getcwd()))) + " supported disc files in current directory")
else:
        search_path_for_discs(sys.argv[1])
        if len(search_path_for_discs(sys.argv[1])) == 0:
            print("No supported disc files found in " + sys.argv[1])
        elif len(search_path_for_discs(sys.argv[1])) > 0:
            print("Found " + str(len(search_path_for_discs(sys.argv[1]))) + " supported disc files in " + sys.argv[1])
        