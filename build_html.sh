#!/bin/bash

./build.sh

src="public"
static="static_html"
build="public_html"
tpl="templates_html"

# add build folder
mkdir -p $build/posts
mkdir -p $build/static

# copy static content to build folder
cp -r $src/static/* $build/static
cp -r $static/* $build/static
cp -r $src/posts/atom.xml $build/posts/atom.xml

# parsing content function
parse_me () {
    for file do
        if  [[ -f "$file" ]]; then
            echo "$file"
            dest=${file/".gmi"/".html"}
            dest="./$build/${dest#./$src/}"
            echo "$dest"
            # remove old destination file if it exists
            if [ -e "$dest" ]; then
                rm "$dest"
            fi
            mkdir -p "${dest%/*}"
            # start new destination file
            touch "$dest"

            # append new content
            {
                cat ./$tpl/head.html
                cat ./$tpl/header.html
                echo $nav
                echo "<article>"
                gmi2mkd "$file" > "$file.md"
                md2html "$file.md"
                rm "$file.md"
                echo "</article>"
                cat ./$tpl/footer.html
            } >> "$dest"
        fi
    done
}

# parse all markdown files and add the templates to them
parse_me $(find ./$src -type f -name "*.gmi")
