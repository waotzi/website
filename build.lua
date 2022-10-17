#!/usr/bin/env lua

local lyaml = require 'lyaml'

-- folder paths
local content_folder = 'content'
local posts_folder = 'content/posts'

local pub_folder = 'public'
local pub_md = pub_folder .. '/md'
local pub_gmi = pub_folder .. '/gmi'
local pub_html = pub_folder .. '/html'

local static_folder = 'static'
local static_any = static_folder .. '/any'
local static_gmi = static_folder .. '/gmi'
local static_html = static_folder .. '/html'

local partials_folder = 'partials'
local partials_any = partials_folder .. '/any'
local partials_gmi = partials_folder .. '/gmi'
local partials_html = partials_folder .. '/html'

local gmi_home_url = 'gemini://waotzi.org'

local main_url = 'https://waotzi.org'

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

        -- add date to posts
        exgest(post_file, meta.title  .. ' was published on ' .. date)

        -- add post links to index file
        local post_link = '[' .. date .. ' - ' .. meta.title .. '](' .. md_path .. ')\n'
        exgest(index_file, post_link)
    end

end

local function copy_static_files(s_folder, p_folder)
    -- make static folder in public folder
    os.execute('mkdir -p ' .. p_folder .. '/static')

    -- copy static files
    if isDir(s_folder) then
        os.execute('cp -r ' .. s_folder .. '/* ' .. p_folder .. '/static')
    end
    
end

local function build_rss()
    os.execute('cp ' .. partials_any .. '/atom.xml ' .. pub_gmi .. '/static/')
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

    -- do rss
    build_rss()

    -- convert md to gmi
    local files = getFiles(pub_md)
    for i, file_path in ipairs(files) do
        p = get_file_path(split(file_path, '/'),  3, 0)
        if not isDir(pub_gmi .. p) then
            os.execute('mkdir -p ' .. pub_gmi .. p)
        end
        local file_name = get_file_path(split(file_path, '/'),  3, 1):gsub('.md', '.gmi')

        os.execute('md2gemini -m -w -f -s ' .. file_path .. ' -d ' .. pub_gmi .. p)
        if file_name ~= '/index.gmi' then
            exgest(pub_gmi .. file_name, '\n\n=> ' .. gmi_home_url .. ' Go home')
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

    -- convert md to html
    local files = getFiles(pub_md)
    for i, file_path in ipairs(files) do
        local p = get_file_path(split(file_path, '/'),  3, 0)

        if not isDir(pub_html .. p) then
            os.execute('mkdir -p ' .. pub_html .. p)
        end
        local pp = get_file_path(split(file_path, '/'),  3, 1):gsub('.md', '.html')
        local has_yaml = ingest(file_path):sub(1, 3) == '---'

        local default_meta = {
            url = main_url .. pp,
            toptitle = 'を  wao ☬ tzi  づ',
            title = 'を  wao ☬ tzi  づ',
            image = main_url .. '/static/waotzi.jpg',
            author = 'waotzi',
            twitter = '@waotzi',
            description = 'Personal cyberspace of waotzi',
            tags = 'waotzi, cyberspace, projects, personal, ukuvota'
        }
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
                    default_meta[k] = v
                    default_meta.toptitle = default_meta.toptitle .. ' - ' .. v
                elseif k == 'image' then
                    default_meta[k] = main_url .. '/static' .. p .. '/' .. v
                else
                    default_meta[k] = v
                end
            end
        end
        local head = ingest(partials_html .. '/head.html')
        for k, v in pairs(default_meta) do
            head = head:gsub('{{ .' .. k .. ' }}', v)
        end
        local html = head ..ingest(partials_html .. '/header.html')
        html = html .. '<article id="' .. body_tag .. '">'
        os.execute('cp ' .. file_path .. ' ' .. file_path .. '.tmp')
        md_file = file_path .. '.tmp'

        -- remove frontmatter if there is any
        if has_yaml then
            cap = os_capture('sed "1{/^---$/!q;};1,/^---$/d" ' .. file_path .. ' > ' .. md_file)
        end
        
        -- convert md to html
        html = html .. os_capture('md2html ' .. md_file)
        html = html .. '</article>'

        os.execute('rm ' .. md_file)

        html = html .. ingest(partials_html .. '/footer.html')
        exgest(pub_html .. pp, html)
    end
end


-- execute the build process
build_md()
build_gmi()
build_html()
