# AFS - androlua

基于 `AndroLua` 的 `Android/data` 文件操作模块

[![](https://img.shields.io/github/license/limao996/afs-androlua.svg)]()
[![](https://img.shields.io/github/v/tag/limao996/afs-androlua?color=0969DA&label=发行版&logo=github)](https://github.com/limao996/afs-androlua/releases)
[![](https://img.shields.io/github/v/tag/limao996/afs-androlua?color=C71D23&label=发行版&logo=gitee)](https://gitee.com/limao996/afs-androlua/releases)

[![](https://img.shields.io/badge/Github-仓库-0969DA?logo=github)](https://github.com/limao996/afs-androlua)
[![](https://img.shields.io/badge/Gitee-仓库-C71D23?logo=gitee)](https://gitee.com/limao996/afs-androlua)
[![](https://img.shields.io/badge/QQ-762259384-0099FF?logo=tencentqq)](https://qm.qq.com/cgi-bin/qm/qr?k=cXJY7qL3Vm3OKtk8_PjJdgnHqoS_sfGL&noverify=0&personal_qrcode_source=3)

[![](https://img.shields.io/badge/QQ群-884183161-0099FF?logo=tencentqq)](https://qm.qq.com/q/3aHOYecyNO)
[![](https://img.shields.io/badge/Telegram-limao__lua-0099FF?logo=telegram)](https://t.me/limao_lua)

## 更新内容
- **`2.0.4`**（2023-11-11)
    + 修复 `Android 11` 兼容性问题
- **`2.0.3`**（2023-09-05)
    + 修复读取内容乱码的Bug
- **`2.0.2`**（2023-09-04)
    + 修复 `writeBytes` 方法的异常
- **`2.0.1`**（2023-08-31)
    + 修复若干Bug
- **`2.0.0`**（2023-08-30)
    + 适配 `Android 13`
    + 重构项目

## AFS 主类
> 权限申请与实例化

### 1. 导入模块
```lua
local afs = require "afs"
```

### 2. 检查权限
```lua
-- 留空即为根目录
afs.check('package')
```

### 3. 请求权限与持久化
```lua
-- 请求并授权
afs.request('package', afs.save)
```
```lua
-- 请求并回调
afs.request('package', function(...)
    if afs.save(...) then
        -- 授权成功
    else
        -- 授权失败
    end
end)
```

### 4. 打开节点
```lua
-- 返回节点对象
local dir = afs.open('package/path/path')
```


## AFS.Node 节点
> 节点操作与IO

### 1. 打开节点
```lua
-- 返回节点对象
local file = dir:open('path/file.txt')
```

### 2. 创建节点
```lua
-- 创建节点并返回对象

-- 创建文件夹节点
local images = dir:create('images/')

-- 创建文件节点
local log = images:create('log.txt')

-- 使用当前节点创建新文件
local new = dir:open('new.txt')
new:create()
```

### 3. 重命名子节点
```lua
-- 返回新的节点对象
dir:rename('old', 'new')
```

### 4. 节点类型
```lua
-- 当前节点是否为文件
dir:isFile()

-- 子节点是否为文件
dir:isFile('demo.avi')
```

### 5. 删除节点
```lua
-- 删除节点并返回结果

-- 删除当前节点
file:remove()

-- 删除子节点
dir:remove('demo.avi')
```

### 6. 节点是否存在
```lua
-- 判断节点是否存在并返回结果

-- 当前节点是否存在
file:exists()

-- 子节点是否存在
dir:exists('demo.avi')
```

### 7. 节点列表
```lua
-- 返回列表
dir:list()
```

### 8. 文件大小
```lua
-- 文件大小
file:length()

-- 文件子节点大小
dir:length('demo.avi')
```

### 9. 节点修改时间
```lua
-- 修改时间
file:lastModified()

-- 子节点修改时间
dir:lastModified('demo.avi')
```

### 10. 文件IO服务
> 提示：文件操作会自动调用该方法

```lua
--- 可读
file:IO(afs.READ)

--- 可写
file:IO(afs.WRITE)

--- 可读写
file:IO(afs.READ | afs.WRITE)
```

> 节点根据读写权限将会拥有以下对应成员
- **`fis`** 文件输入流
- **`fos`** 文件输出流
- **`fic`** 文件输入通道
- **`foc`** 文件输入通道

### 11. 拷贝节点数据
> 提示：目标可以是节点对象和文件通道
```lua
-- 打开文件节点
local input = dir:open('in.txt')
local output = dir:open('out.txt')

-- 复制内容到文件节点
input:copyTo(output)

-- 关闭节点IO
input:close()
output:close()
```

### 12. 读取数据
```lua
-- 读取全部
file:read()

-- 读取6字节（效率低）
file:read(6)

-- 读取6字节（仅文本）
file:readString(6)

-- 读取到字节数组
local bytes = byte[4096]
file:readBytes(bytes)
```

### 13. 写入数据
```lua
-- 写入字符串(效率低)
file:write('测试')

-- 写入字符串(仅文本)
file:wrifilering('文本')

-- 写入字节数组
local bytes = byte[4096]
file:writeBytes(bytes)
```

### 14. 跳转文件位置
> 提示：返回跳转后位置
```lua
-- 不跳转，仅返回位置
file:seek()

-- 从头部开始
file:seek('set', 1)

-- 从当前位置开始
file:seek('cur', 0)

-- 从尾部开始
file:seek('end', -1)
```

### 15. 写入文件缓冲
```lua
-- 写入缓冲到磁盘
file:flush()
```

### 16. 截断文件内容
```lua
-- 截断到位置 0
file:truncate(0)
```

### 17. 关闭文件IO服务
```lua
-- 关闭节点IO
file:close()
```