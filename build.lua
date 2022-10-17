#!/usr/bin/env lua

local lyaml = require 'lyaml'

-- folder paths
local content_folder <const>  = 'content'
local posts_folder <const>  = 'content/posts'

local pub_folder <const>  = 'public'
local pub_md <const>  = pub_folder .. '/md'
local pub_gmi <const>  = pub_folder .. '/gmi'
local pub_html <const>  = pub_folder .. '/html'

local static_folder <const>  = 'static'
local static_any <const>  = static_folder .. '/any'
local static_gmi <const>  = static_folder .. '/gmi'
local static_html <const>  = static_folder .. '/html'

local partials_folder <const>  = 'partials'
local partials_any <const>  = partials_folder .. '/any'
local partials_gmi <const>  = partials_folder .. '/gmi'
local partials_html <const>  = partials_folder .. '/html'

local gmi_main_url <const> = 'gemini://waotzi.org'

local main_url <const> = 'https://waotzi.org'

local xml_gmi_file <const> = 'atom_gmi.xml'
local xml_html_file <const> = 'atom_html.xml'


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


local default_meta <const>  = {
    id = 'waotzi',
    url = main_url,
    toptitle = 'を  wao ☬ tzi  づ',
    title = 'を  wao ☬ tzi  づ',
    image = main_url .. '/static/waotzi.jpg',
    author = 'waotzi',
    twitter = '@waotzi',
    description = 'Personal cyberspace of waotzi',
    tags = 'waotzi, cyberspace, projects, personal, ukuvota',
    updated = get_date()
}

-- utils


local function getFiles(dir)
    local t = {}
    local p = io.popen('find "' .. dir ..'" -type f')  --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.     
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
    os.execute('touch '.. pub_md .. '/' .. file_name)
    local rss_meta = shallow_copy(default_meta)
    local xml_data = ingest(partials_any .. '/atom.xml')
    for k, v in pairs(rss_meta) do
        if k == 'url' then
            v = main_url
        end
        xml_data = xml_data:gsub('{{ .' .. k .. ' }}', v)
    end
    return xml_data, rss_meta
end

local function add_xml_entry(xml_data, rtn_meta, meta, file_url, gemini)
    for k, v in pairs(meta) do
        rtn_meta[k] = v
    end
    local date = split(rtn_meta['date'], '/')
    date = os.date('%Y-%m-%dT%H:%M:%S', os.time({year = date[1], month = date[2], day = date[3], hour})) .. 'Z'

    xml_data = xml_data .. '<entry>\n'
    xml_data = xml_data .. '<title>' .. rtn_meta['title'] .. '</title>\n'
	xml_data = xml_data .. '<link href="' .. file_url .. '"/>\n'
	xml_data = xml_data .. '<id>' .. file_url .. '</id>\n'
	xml_data = xml_data .. '<updated>' .. date.. '</updated>\n'
    xml_data = xml_data .. '<summary>' .. rtn_meta['description'] .. '</summary>\n'

    if gemini then
        xml_data = xml_data .. '<content src="' .. file_url .. '" type="text/gemini"></content>\n'
    end
    xml_data = xml_data .. '</entry>\n'
    return xml_data
end

-- process the markdown files for further processing
local function build_md()
    -- remove last public/md
    if isDir(pub_md) then
        os.execute('rm -r ' .. pub_md)
    end

    -- make public/md folder
    os.execute('mkdir -p ' .. pub_md)

    -- copy content to public/md
    os.execute('cp -r ' .. content_folder .. '/* ' .. pub_md)

    -- get new index file
    local index_file = pub_md .. '/index.md'
    exgest(index_file, '## Posts')

    -- copy rss file
    local xml_gmi, xml_gmi_meta = update_rss(xml_gmi_file, gmi_main_url)
    local xml_html, xml_html_meta = update_rss(xml_html_file, main_url) 

    -- find posts in content folder and add the links to public/md/index.md
    local posts = getFiles(posts_folder)
    for i = #posts, 1, -1 do
        post_path = posts[i]
        file_content = ingest(post_path)

        local split_content = split(file_content, '---')
        local md_path = get_file_path(split(post_path, '/'), 2, 1):sub(2)
        local post_file = pub_md .. '/' .. md_path

        -- make yaml content
        local yaml = split_content[1]
        local meta = lyaml.load(yaml)
        local date = meta.date:gsub('/', '-')

        local xml_md_path_gmi = md_path:gsub('.md', '.gmi')
        local xml_md_path_html = md_path:gsub('.md', '.html')
        xml_gmi = add_xml_entry(xml_gmi, xml_gmi_meta, meta, xml_md_path_gmi, true)
        xml_html = add_xml_entry(xml_html, xml_html_meta, meta, xml_md_path_html, false)
        -- add date to posts
        exgest(post_file, meta.title  .. ' was published on ' .. date)

        -- add post links to index file
        local post_link = '[' .. date .. ' - ' .. meta.title .. '](' .. md_path .. ')\n'
        exgest(index_file, post_link)
    end
    xml_gmi = xml_gmi .. '</feed>'
    xml_html = xml_html .. '</feed>'
    

    exgest(pub_md .. '/' .. xml_gmi_file, xml_gmi)
    exgest(pub_md .. '/' .. xml_html_file, xml_html)
end

local function copy_static_files(s_folder, p_folder)
    -- make static folder in public folder
    os.execute('mkdir -p ' .. p_folder .. '/static')

    -- copy static files
    if isDir(s_folder) then
        os.execute('cp -r ' .. s_folder .. '/* ' .. p_folder .. '/static')
    end
    
end

-- process public_md for public_gmi
local function build_gmi()
    -- remove last public/gmi
    if isDir(pub_gmi) then
        os.execute('rm -r ' .. pub_gmi)
    end

    -- copy static files
    copy_static_files(static_any, pub_gmi)
    copy_static_files(static_gmi, pub_gmi)
    os.execute('mv ' .. pub_md .. '/' .. xml_gmi_file .. ' ' .. pub_gmi .. '/' .. 'atom.xml')

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
                exgest(pub_gmi .. file_name, '\n\n=> ' .. gmi_main_url .. ' Go home')
            end
        end
    end
end


local function build_html()
    -- remove last public/html
    if isDir(pub_html) then
        os.execute('rm -r ' .. pub_html)
    end

    -- copy static files
    copy_static_files(static_any, pub_html)
    copy_static_files(static_html, pub_html)

    os.execute('mv ' .. pub_md .. '/' .. xml_html_file .. ' ' .. pub_html .. '/' .. 'atom.xml')

    -- convert md to html
    local files = getFiles(pub_md)
    for i, file_path in ipairs(files) do
        if file_path:find('.md', file_path:len() - 3) then
            local p = get_file_path(split(file_path, '/'),  3, 0)

            if not isDir(pub_html .. p) then
                os.execute('mkdir -p ' .. pub_html .. p)
            end
            local pp = get_file_path(split(file_path, '/'),  3, 1):gsub('.md', '.html')
            local has_yaml = ingest(file_path):sub(1, 3) == '---'
            local rtn_meta = shallow_copy(default_meta)
            rtn_meta['url'] = rtn_meta['url'] .. pp

            local body_tag = ""
            if has_yaml then
                file_content = ingest(file_path)

                local split_content = split(file_content, '---')

                -- make yaml content
                local yaml = split_content[1]
                local meta = lyaml.load(yaml)
                for k, v in pairs(meta) do
                    if k == 'title' then
                        body_tag = v:lower():gsub(' ', '_')
                        rtn_meta[k] = v
                        rtn_meta.toptitle = rtn_meta.toptitle .. ' - ' .. v
                    elseif k == 'image' then
                        rtn_meta[k] = main_url .. '/static' .. p .. '/' .. v
                    else
                        rtn_meta[k] = v
                    end
                end
            end
            local head = ingest(partials_html .. '/head.html')
            for k, v in pairs(rtn_meta) do
                head = head:gsub('{{ .' .. k .. ' }}', v)
            end
            local html = head ..ingest(partials_html .. '/header.html')
            html = html .. '<article id="' .. body_tag .. '">\n'
            os.execute('cp ' .. file_path .. ' ' .. file_path .. '.tmp')
            md_file = file_path .. '.tmp'

            -- remove frontmatter if there is any
            if has_yaml then
                os.execute('sed "1{/^---$/!q;};1,/^---$/d" ' .. file_path .. ' > ' .. md_file)
            end
            
            -- convert md to html
            html = html .. os_capture('md2html ' .. md_file)
            html = html .. '</article>\n'

            os.execute('rm ' .. md_file)

            html = html .. ingest(partials_html .. '/footer.html')
            exgest(pub_html .. pp, html)
        end
    end
end


-- execute the build process
build_md()
build_gmi()
build_html()
