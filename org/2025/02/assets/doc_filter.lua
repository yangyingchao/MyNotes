-- my utilities when converting to docx

local should_remove = false
local page_break = pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
local paragraph = '<w:p><w:pPr><w:rPr><w:rFonts w:hint="default"/><w:lang w:val="en-US"/></w:rPr></w:pPr></w:p>'
local toc = pandoc.RawBlock('openxml',
    '<w:sdt><w:sdtPr><w:docPartObj><w:docPartGallery w:val="Table of Contents" /><w:docPartUnique /></w:docPartObj></w:sdtPr><w:sdtContent><w:p><w:pPr><w:pStyle w:val="TOCHeading" /></w:pPr><w:r><w:rPr><w:rFonts w:hint="eastAsia" /></w:rPr><w:t xml:space="preserve">目录</w:t></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true" /><w:instrText xml:space="preserve">TOC \\o &quot;1-3&quot; \\h \\z \\u</w:instrText><w:fldChar w:fldCharType="separate" /><w:fldChar w:fldCharType="end" /></w:r></w:p></w:sdtContent></w:sdt>')

-- Filter function called on each RawBlock element.
function RawBlock(el)
    if should_remove then
        return {} -- 返回空以过滤掉这个块
    end

    if el.format:match 'tex' then
        if el.text:match '\\newpage' then -- page break
            return page_break
        elseif el.text:match '\\tableofcontents' then
            return toc
        else
            local number = string.match(el.text, '\\vspace{%s*(%d+)%s*mm}') -- vspace
            if number then
                return pandoc.RawBlock('openxml', string.rep(paragraph, tonumber(number) / 10))
            end
        end
    end
end

function Div(div)
    if should_remove or div.attr.classes[1] == "NOTES" then
        return {} -- hide BEGIN_NOTES from export to docx
    end
end

function Header(elem)
    local blocks = elem.content
    should_remove = blocks:find_if(function(b)
        if b.attr then
            local value = b.attr.attributes["tag-name"]
            if value and value == "nodocx" then
                return true
            end
        end
        return false
    end)

    if should_remove then
        return {}
    end
end

function MaybeSkip(_)
    if should_remove then
        return {} -- 如果标志为 true，返回空以过滤掉这个子列表
    end
end

function Table(tbl)
    if should_remove then
        return {}
    end

    local first_row = true
    local pattern = "^[%s/<>\r\n]*$" -- %s 表示空白字符

    for _, body in ipairs(tbl.bodies) do
        local new_body = {}
        for _, row in ipairs(body.body) do
            local s = ""
            for _, cell in ipairs(row.cells) do
                s = s .. pandoc.utils.stringify(cell)
            end

            if first_row and string.match(s, pattern) ~= nil then
            else
                table.insert(new_body, row) -- 将不匹配的行加入临时表
            end

            first_row = false
        end
        body.body = new_body -- 用临时表替换原来的 body.body
    end

    return tbl
end

function CodeBlock(elem)
    if should_remove or elem.attributes.results == "none" then
        return {}
    end
end

return { {
    RawBlock = RawBlock,
    Div = Div,
    Header = Header,
    Str = MaybeSkip,
    BulletList = MaybeSkip,
    Plain = MaybeSkip,
    Para = MaybeSkip,
    Table = Table,
    CodeBlock = CodeBlock,
} }
