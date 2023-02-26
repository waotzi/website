#!/usr/bin/env lua

local lyaml = require 'lyaml'

-- folder paths
local root_dir = '.'
local base_url = 'https://waotzi.org'
local base_url_gmi = 'gemini://waotzi.org'

local content_dir = root_dir .. '/content'
local posts_dir = root_dir .. '/content/posts'
local pub_dir = root_dir .. '/public'
local static_dir = root_dir .. '/static'
local partials_dir = root_dir .. '/partials'

local xml_file = 'atom.xml'
local xml_file_gmi = 'atom_gmi.xml'


local function string_insert(str1, str2, pos)
    return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

local function get_date()
    return os.date('%Y-%m-%dT%H:%M:%S') .. string_insert(os.date('%z'), ':', 3)
end

local function shallow_copy(t)
    local t2 = {}
    for k,v in pairs(t) do
      t2[k] = v
    end
    return t2
end


local default_meta = {
    id = 'waotzi',
    url = base_url,
    toptitle = "Waotzi's Path",
    title = "Waotzi's Path",
    image = base_url .. '/waotzi_warrior.jpeg',
    author = 'waotzi',
    twitter = '@waotzi',
    description = 'Personal cyberspace of waotzi',
    tags = 'waotzi, cyberspace, projects, personal, ukuvota',
    updated = get_date()
}

-- utils


local function getFiles(dir)
    local t = {}
    --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.  
    local p = io.popen("find '" .. dir .."' -type f | sort -n")     
    for file in p:lines() do                         --Loop through all files
        table.insert(t, file)       
    end
    return t
 end

local function ingest(path)
    local file = io.open(path, 'rb') -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read '*a' -- *a or *all reads the whole file
    file:close()
    return content
end

local function exgest(file, content)
    local f = io.open(file, 'a')
    io.output(f)
    io.write(content .. '\n')
    io.close(f)
 end

local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
       table.insert(result, each)
    end
    return result
 end
  

local function isDir(dir_path)
  local f = io.popen('[ -d "' .. dir_path .. '" ] && echo -n y')
  local result = f:read(1)
  f:close()
  return result == "y"
end

-- get desired file path
local function get_file_path(f, fi, i)
    local ff = ''
    while fi < #f + i do
        ff = ff .. '/' .. f[fi]
        fi = fi + 1
    end
    return ff
end

local function os_capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end

local function update_rss(file_name, main_url)
    os.execute('touch '.. pub_dir .. '/' .. file_name)
    local rss_meta = shallow_copy(default_meta)
    local xml_data = ingest(partials_dir .. '/atom.xml')
    for k, v in pairs(rss_meta) do
        if k == 'url' then
            v = base_url
        end
        xml_data = xml_data:gsub('{{ .' .. k .. ' }}', v)
    end
    return xml_data, rss_meta
end

local function add_xml_entry(xml_data, xml_meta, meta, xml_path, summary, is_gemini)
    local file_url = xml_path:gsub('.md', is_gemini and '.gmi' or '.html')
    local date = split(meta.date, '/')
    date = os.date('%Y-%m-%dT%H:%M:%S', os.time({year = date[1], month = date[2], day = date[3], hour = 0})) .. 'Z'
    local content_tag = ""
    if is_gemini then
        content_tag = string.format("<content src=\"%s\" type=\"text/gemini\"></content>", file_url)
    else 
        content_tag = string.format("<summary><![CDATA[%s]]></summary>", summary)
    end
    local entry_xml = string.format([[
        <entry>
            <title>%s</title>
            <link href="%s"/>
            <id>%s</id>
            <updated>%s</updated>
            %s
        </entry>
    ]], meta['title'], file_url, file_url, date, content_tag)

    xml_data = xml_data .. entry_xml
    return xml_data
end


local function reset_dir(dir)
    -- remove last public
    if isDir(dir) then
        os.execute('rm -r ' .. dir)
    end

    -- make public folder
    os.execute('mkdir -p ' .. dir)

end

-- process the markdown files for further processing
local function build_md()
    local pub_md = pub_dir .. '/md'
    reset_dir(pub_md)

    -- copy content to public/md
    os.execute('cp -r ' .. content_dir .. '/* ' .. pub_md)

    -- get new index file
    local posts_yaml = pub_md .. '/posts.yml'

    -- copy rss file
    local xml_html, xml_meta_html = update_rss(xml_file, main_url) 
    local xml_gmi, xml_meta_gmi = update_rss(xml_file_gmi, main_url_gmi)

    -- find posts in content folder and add the links to public/md/index.md
    local posts = getFiles(posts_dir)
    local post_file, summary_file

    for i = #posts, 1, -1 do
        post_path = posts[i]
        file_content = ingest(post_path)
        local split_content = split(file_content, '---')
        local md_path = post_path:gsub(root_dir .. '/content', "", 1)

        local post_file = pub_md .. '/' .. md_path
        -- make yaml content   
        local yaml = split_content[1]
        local meta = lyaml.load(yaml)
        local date = split(meta.date, '/')
        local fmt_date = os.date('%b %d, %Y', os.time({year = tonumber(date[1]), month = tonumber(date[2]), day = tonumber(date[3])}))
    
        local summary_file = post_path .. '.tmp'
        os.execute('touch ' .. summary_file)
        os.execute(string.format("sed '1{/^---$/!q;} ; 1,/^---$/d' %s > %s", post_path, summary_file))
        summary = os_capture(string.format("./bin/md2html %s", summary_file))
        os.execute('rm ' .. summary_file)

        xml_gmi = add_xml_entry(xml_gmi, xml_meta_gmi, meta, md_path, summary, true)
        xml_html = add_xml_entry(xml_html, xml_meta_html, meta, md_path, summary, false)
        exgest(post_file, string.format("%s was published on %s\n\n[↩ return to posts](/posts.md)", meta.title, fmt_date))
    
        print(md_path)

        local post_data = string.format("- name: %s\n  category: %s\n  published: %s\n  synopsis: %s\n  image: /posts/%s\n  read_more: %s\n", 
            meta.title, meta.tags, fmt_date, meta.description, meta.image, md_path:gsub("%.md$", ".html"))
        exgest(posts_yaml, post_data)
    end
    
    
    xml_html = xml_html .. '</feed>'    
    xml_gmi = xml_gmi .. '</feed>'
    
    exgest(pub_dir .. '/' .. xml_file, xml_html)
    exgest(pub_dir .. '/' .. xml_file_gmi, xml_gmi)
end

local function copy_static_files(s_folder, p_folder)
    -- copy static files
    if isDir(s_folder) then
        os.execute('cp -r ' .. s_folder .. '/* ' .. p_folder)
    end
    
end

-- process public_md for public_gmi
local function build_gmi()
    local pub_gmi = pub_dir .. '/gmi'
    local pub_md = pub_dir .. '/md'
    reset_dir(pub_gmi)

    -- copy static files
    copy_static_files(static_dir, pub_dir)
    os.execute('mv ' .. pub_dir .. '/' .. xml_file_gmi .. ' ' .. pub_gmi .. '/' .. 'atom.xml')

    -- convert md to gmi
    local files = getFiles(pub_md)
    for i, file_path in ipairs(files) do
        if file_path:find('.md', file_path:len() - 3) then
            p = get_file_path(split(file_path, '/'),  3, 0)

            if not isDir(pub_gmi .. p) then
                os.execute('mkdir -p ' .. pub_gmi .. p)
            end
            local file_name = get_file_path(split(file_path, '/'),  3, 1):gsub('.md', '.gmi')

            os.execute('md2gemini -m -w -f -s ' .. file_path .. ' -d ' .. pub_gmi .. p)
            if file_name ~= '/index.gmi' then
                exgest(pub_gmi .. file_name, '\n\n=> ' .. base_url_gmi .. ' Go home')
            end
        end
    end
end


local function build_html()
    local pub_html = pub_dir .. '/html'
    local pub_md = pub_dir .. '/md'

    reset_dir(pub_html)
    -- copy static files
    copy_static_files(static_dir, pub_html)
    os.rename(pub_dir .. '/' .. xml_file, pub_html .. '/atom.xml')

    -- convert md to html
    local files = getFiles(pub_md)
    for i, file_path in ipairs(files) do
        if file_path:find('.md', file_path:len() - 3) then        
            local new_file_path = file_path:gsub('/md', '/html', 1):gsub('.md', ".html", 1)
            local relative_path = new_file_path:gsub(pub_html, '', 1)
            local has_yaml = ingest(file_path):sub(1, 3) == '---'
            local rtn_meta = shallow_copy(default_meta)
            rtn_meta['url'] = rtn_meta['url'] .. relative_path
            local yml_data = nil
            local body_tag = ""
            if has_yaml then
                file_content = ingest(file_path)
                -- make yaml content
                local meta = lyaml.load(split(file_content, '---')[1])
                for k, v in pairs(meta) do
                    if k == 'title' then
                        body_tag = v:lower():gsub(' ', '_')
                        rtn_meta[k] = v
                        rtn_meta.toptitle = rtn_meta.toptitle .. ' - ' .. v
                    elseif k == 'image' then
                        rtn_meta[k] = relative_path
                    else
                        rtn_meta[k] = v
                    end
                    if k == "yml_data" then
                        yml_data = v
                    end
                end
            end
            local html = ingest(partials_dir .. '/head.html')
            for k, v in pairs(rtn_meta) do
                html = html:gsub('{{ .' .. k .. ' }}', v)
            end
            html = html .. ingest(partials_dir .. '/header.html')
            html = html .. '<article id="' .. body_tag .. '">\n'
            os.execute('cp ' .. file_path .. ' ' .. file_path .. '.tmp')
            md_file = file_path .. '.tmp'

            -- remove frontmatter if there is any
            if has_yaml then
                os.execute('sed "1{/^---$/!q;};1,/^---$/d" ' .. file_path .. ' > ' .. md_file)
            end
            
            -- convert md to html
            html = html .. os_capture('./bin/md2html ' .. md_file)
            -- add yml content if there is any
            if yml_data then
                print(pub_md .. '/' .. yml_data)
                local file = io.open(pub_md .. '/' .. yml_data, "r")
                local content = file:read("*all")
                file:close()

                local items = lyaml.load(content)
                html = html .. '<div class="projects">'
                for _, item in ipairs(items) do
                    html = html .. '<div class="project '  .. string.lower(item.status or '') .. '">\n'
                    if item.image then
                        html = html .. '<img src="' .. item.image .. '" alt="' .. item.name .. '">\n'
                    end
                    html = html .. '<h2>' .. item.name .. '</h2>\n'
                    if item.description then
                        html = html .. '<p>' .. item.description .. '</p>\n'
                    end
                    if item.published then
                        html = html .. '<p><b>Published:</b> ' .. item.published .. '</p>\n'
                    end
                    if item.address then
                        html = html .. '<p>' .. item.address .. '</p>\n'
                    end
                    if item.url then
                        html = html .. '<a href="' .. item.url .. '">' .. item.name .. '</a>\n'
                    end
                    if item.links then
                        html = html .. '<ul class="links">\n'
                        for _, link in ipairs(item.links) do
                            html = html .. '<li><a href="' .. link.url .. '">' .. link.name .. '</a></li>\n'
                        end
                        html = html .. '</ul>\n'
                    end
                    if item.category then
                        html = html .. '<p><b>Category:</b> ' .. item.category .. '</p>\n'
                    end
                    local color = 'black'
                    if item.status == 'Active' then
                            color = 'green'
                    end
                    if item.status then
                        html = html .. '<p><b>Status:</b> <span class="text-' .. string.lower(item.status) .. '">' .. item.status .. ' ' .. (item.eol or '') .. '</span></p>\n'
                    end

                    if item.synopsis then
                        html = html .. '<br/><p>' .. item.synopsis .. '</p><br/>\n'
                    end
                    if item.read_more then
                        html = html .. '<a href="' .. item.read_more .. '"> Read more... </a><br/>\n'
                    end
                    html = html .. '</div>\n'
                end

                html = html .. '</div>\n'

            end
            html = html .. '</article>\n'

            os.execute('rm ' .. md_file)

            html = html .. ingest(partials_dir .. '/footer.html')
            exgest(new_file_path, html)
        end
    end
end


reset_dir(pub_dir)

-- execute the build process
build_md()
--build_gmi()
build_html()
