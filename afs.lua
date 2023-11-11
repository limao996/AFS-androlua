---
--- Project Name: AFS-androlua
--- Created by 狸猫呐.
--- DateTime: 2023/8/30 13:00
---
--- Open Source:
--- [Gitee](https://gitee.com/limao996/afs-androlua)
--- [Github](https://github.com/limao996/afs-androlua)
---

local _G, setmetatable, pcall, byte, getmetatable = _G, setmetatable, pcall, byte, getmetatable
local bindClass, random, astable, clear = luajava.bindClass, math.random, luajava.astable, luajava.clear

-- 导入java类
local Build = bindClass "android.os.Build"
local Intent = bindClass "android.content.Intent"
local Uri = bindClass 'android.net.Uri'
local DocumentsContract = bindClass 'android.provider.DocumentsContract'
local String = bindClass "java.lang.String"
local ByteBuffer = bindClass "java.nio.ByteBuffer"
local context = activity or service

--- 内容提供者
local resolver = context.getContentResolver()
--- SDK版本
local SDK = Build.VERSION.SDK_INT

---@class AFS 主类
---@field READ number 读取权限
---@field WRITE number 写入权限
local _M = {
    READ = 1,
    WRITE = 2
}

---@class AFS.Node 节点
---@field path string 路径
---@field fis userdata 文件输入流
---@field fos userdata 文件输出流
---@field fic userdata 文件输入通道
---@field foc userdata 文件输出通道
---@field pos number 文件句柄位置
local _N = { pos = 1 }

--- 根节点的Uri地址
local rootUri = "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata"

--- 创建Uri地址
---@param path string 节点路径
local function makeUri(path)
    path =
        path:gsub('^/', '')
        :gsub('/$', '')
    local uri = rootUri
    if SDK >= 33 and path ~= '' and path then
        local fmt = '%s%%2F%s'
        uri = fmt:format(uri, (path:gsub('/', '%%2F')))
    end
    return Uri.parse(uri)
end

--- 创建文件Uri地址
---@param path string 节点路径
local function makeFileUri(path)
    path =
        path:gsub('^/', '')
        :gsub('/$', '')
    local package = '%2F' .. path:match('[^/]+')
    if SDK < 33 then
        package = ''
    end
    local uri = rootUri
        .. package
        .. '/document/primary%3AAndroid%2Fdata%2F'
        .. path:gsub('/', '%%2F')
    return Uri.parse(uri)
end

--- 检查权限
---@param path string 路径
---@return boolean 是否拥有权限
function _M.check(path)
    if SDK < 30 then return true end

    local uri = makeUri(path)

    local list = resolver.getPersistedUriPermissions()
    for i = 0, #list - 1 do
        local v = list[i]
        if v.isReadPermission() and v.getUri().equals(uri) then
            return true
        end
    end
    return false
end

--- 请求权限
---@param path string 路径
---@param callback fun(any,any,any):void 回调
---@return void
function _M.request(path, callback)
    local uri = makeUri(path)

    local intent = Intent("android.intent.action.OPEN_DOCUMENT_TREE")
    intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
        | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
    local id = DocumentsContract.getTreeDocumentId(uri)
    intent.putExtra("android.provider.extra.INITIAL_URI",
        DocumentsContract.buildDocumentUriUsingTree(uri, id))

    local tag = random(0x1000, 0xffff)
    context.startActivityForResult(intent, tag)
    local super = _G.onActivityResult
    function _G.onActivityResult(...)
        if super then
            super(...)
        end
        if ({ ... })[1] == tag then
            _G.onActivityResult = super
            callback(...)
        end
    end
end

--- 持久化授权
---@return boolean
function _M.save(_, _, intent)
    if not intent then return false end
    local uri = intent.getData()
    if uri then
        resolver.takePersistableUriPermission(uri,
            intent.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
        return true
    end
    return false
end

--- 打开节点对象
---@param path string 路径
---@return AFS.Node 节点对象
function _M.open(path)
    local o = { path = path }
    return setmetatable(o, _N)
end

--- 打开节点对象
---@param path string 路径
---@return AFS.Node 节点对象
function _N:open(path)
    local o = { path = self.path .. '/' .. path }
    return setmetatable(o, _N)
end

--- 创建新节点
---@param path string|nil 路径
---@return AFS.Node 节点对象
function _N:create(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local type, name
    if path:sub(-1) == '/' then
        type = "vnd.android.document/directory"
        path = path:sub(1, -2)
    else
        type = "*/*"
    end
    path, name = path:match '^(.-)/([^/]+)$'
    local err, res = pcall(DocumentsContract.createDocument, resolver, makeFileUri(path), type, name)
    local node
    if err and res then
        node = _M.open(res.getPath():match('document/primary:Android/data/(.+)'))
    end
    return node
end

--- 删除节点
---@param path string|nil 路径
---@return boolean 删除结果
function _N:remove(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local err, res = pcall(DocumentsContract.deleteDocument, resolver, makeFileUri(path))
    if err then return res end
    return false
end

--- 重命名节点
---@param path string 路径
---@param name string 新名字
---@return AFS.Node 新对象
function _N:rename(path, name)
    path = self.path .. '/' .. path
    local err, res = pcall(DocumentsContract.renameDocument, resolver, makeFileUri(path), name)
    local node
    if err and res then
        node = res.getPath():match('document/primary:Android/data/(.+)')
    end
    return _M.open(node)
end

--- 节点是否存在
---@param path string|nil 路径
---@return boolean
function _N:exists(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local a, b = pcall(function()
        local cursor = resolver.query(makeFileUri(path), { "document_id" }, nil, nil, nil)
        local n = cursor.getCount() > 0
        cursor.close()
        return n
    end)
    if a then return b end
    return false
end

--- 节点是否为文件
---@param path string|nil 路径
---@return boolean
function _N:isFile(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local a, b = pcall(function()
        local cursor = resolver.query(makeFileUri(path), { "mime_type" }, nil, nil, nil)
        cursor.moveToFirst()
        local n = cursor.getString(0)
        cursor.close()
        return n ~= 'vnd.android.document/directory'
    end)
    if a then return b end
    return false
end

--- 节点列表
---@param path string|nil 路径
---@return string[]
function _N:list(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local uri = makeFileUri(path)
    local tree = DocumentsContract.buildChildDocumentsUriUsingTree(uri, DocumentsContract.getDocumentId(uri))
    local cursor = resolver.query(tree, { "document_id" }, nil, nil, nil)

    local list = {}
    while cursor.moveToNext() do
        list[#list + 1] = cursor.getString(0):match('([^/]+)$')
    end
    cursor.close()
    return list
end

--- 节点修改时间
---@param path string|nil 路径
---@return number 时间戳
function _N:lastModified(path)
    if path then
        path = self.path .. '/' .. path
    else
        path = self.path
    end
    local uri = makeFileUri(path)
    local cursor = resolver.query(uri, { "last_modified" }, nil, nil, nil)
    cursor.moveToFirst()
    local n = cursor.getLong(0)
    cursor.close()
    return n // 1000
end

--- 文件IO服务
---@field flags number 权限
---@return void
function _N:IO(flags)
    if flags & 1 > 0 and not self.fic then
        local uri = makeFileUri(self.path)
        self.fis = resolver.openInputStream(uri)
        self.fic = self.fis.getChannel()
    end
    if flags & 2 > 0 and not self.foc then
        local uri = makeFileUri(self.path)
        self.fos = resolver.openOutputStream(uri)
        self.foc = self.fos.getChannel()
    end
end

--- 文件长度
---@param path string|nil 路径
---@return number 长度
function _N:length(path)
    if not path then
        self:IO(1)
        return self.fic.size()
    end
    path = self.path .. '/' .. path
    local uri = makeFileUri(path)
    local cursor = resolver.query(uri, { "_size" }, nil, nil, nil)
    cursor.moveToFirst()
    local n = cursor.getLong(0)
    cursor.close()
    return n
end

--- 文件截断
---@param pos number 截断位置
---@return self
function _N:truncate(pos)
    self:IO(2)
    self.foc.truncate(pos)
    return self
end

--- 移动文件句柄
---@param mode string|"set"|"cur"|"end" @移动方式
---@param n number 数值
---@return number 位置
function _N:seek(mode, n)
    if not n then
        if mode == "set" then
            n = 1
        elseif mode == "end" then
            n = -1
        else
            n = 0
        end
    end
    if mode == 'set' then
        self.pos = n
    elseif mode == 'end' then
        self.pos = self:length() + n + 1
    else
        self.pos = self.pos + n
    end
    return self.pos
end

--- 字符串转字节数组
---@param s string 字符串
---@return userdata 字节数组
local function string2bytes(s)
    return byte { s:byte(1, #s) }
end

--- 字节数组转字符串
---@param b userdata 字节数组
---@return string 字符串
local function bytes2string(b)
    local t = astable(b)
    for i = 1, #t do
        t[i] = t[i] & 0xff
    end
    return string.char(table.unpack(t))
end

--- 读取文件
---@param n number|nil 读取长度，为空读取全部
---@return string 字符串
function _N:read(n)
    if not n then
        n = self:length() - self.pos + 1
    else
        local new = self.pos + n
        local size = self:length()
        if new > size + 1 then
            n = size - self.pos + 1
        end
    end
    if n <= 0 then return "" end
    local b = byte[n]
    self:readBytes(b)
    local s = bytes2string(b)
    clear(b)
    return s
end

--- 读取文件文本
---@param n number|nil 读取长度，为空读取全部
---@return string 字符串
function _N:readString(n)
    if not n then
        n = self:length() - self.pos + 1
    else
        local new = self.pos + n
        local size = self:length()
        if new > size + 1 then
            n = size - self.pos + 1
        end
    end
    if n <= 0 then return "" end
    local b = byte[n]
    self:readBytes(b)
    local s = String(b).toString()
    clear(b)
    return s
end

--- 读取文件字节
---@param b userdata 字节数组
---@return number 读取长度
function _N:readBytes(b)
    self:IO(1)
    self.fic.position(self.pos - 1)
    local buff = ByteBuffer.wrap(b)
    local n = self.fic.read(buff)
    self.pos = self.pos + n
    return n
end

--- 写入文件
---@param s string 字符串
---@return self
function _N:write(s)
    local b = string2bytes(s)
    self:writeBytes(b)
    clear(b)
    return self
end

--- 写入文件文本
---@param s string 字符串
---@return self
function _N:writeString(s)
    local b = String(s).getBytes()
    self:writeBytes(b)
    clear(b)
    return self
end

--- 写入字节到文件
---@param buffer userdata 字节数组
---@return number 写入长度
function _N:writeBytes(buffer)
    self:IO(2)
    self.foc.position(self.pos - 1)
    local buff = ByteBuffer.wrap(buffer)
    local n = self.foc.write(buff)
    self.pos = self.pos + n
    return n
end

--- 写入文件缓冲
---@return self
function _N:flush()
    self:IO(2)
    self.foc.force(false)
    return self
end

--- 关闭文件
---@return self
function _N:close()
    if self.fic then
        self.fic.close()
        self.fis.close()
    end
    if self.foc then
        self.foc.close()
        self.fos.close()
    end
    self.foc = nil
    self.fic = nil
    self.fos = nil
    self.fis = nil
    self.pos = 1
    return self
end

--- 复制数据到文件
---@param file AFS.Node|userdata 节点对象|文件通道
---@return self
function _N:copyTo(file)
    self:IO(1)
    local foc = file
    local fic = self.fic
    if getmetatable(file) == _N then
        file:IO(2)
        foc = file.foc
    end
    local n = 0
    while true do
        if n >= fic.size() then
            break
        end
        n = n + fic.transferTo(n, fic.size(), foc)
    end
    foc.force(false)
    return self
end

_N.__index = _N
return _M
