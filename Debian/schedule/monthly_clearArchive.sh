#!/bin/bash

target_directory="/mnt/Documents/Files"

find "$target_directory" -type d -name ".sync" -exec rm -rf {}/Archive \;
