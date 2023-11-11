---
--- Project Name: AFS-androlua
--- Created by 狸猫呐.
--- DateTime: 2023/8/30 13:00
---
--- Open Source:
--- [Gitee](https://gitee.com/limao996/afs-androlua)
--- [Github](https://github.com/limao996/afs-androlua)
---

require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"

activity.setContentView {
    LinearLayout,
    orientation = "vertical",
    gravity = "center",
    {
        Button,
        text = "授权",
        id = "btn1",
    },
    {
        Button,
        text = "测试",
        id = "btn2",
    },
}


-- 导入模块
local afs = require "afs"

-- 活动开始
function onStart()
    -- 检查目录权限
    local checked = afs.check('com.androlua')
    -- 设置按钮状态
    btn1.setEnabled(not checked)
    btn2.setEnabled(checked)
end

-- 点击授权
function btn1:onClick()
    -- 请求权限并持久化授权
    afs.request('com.androlua', afs.save)
end

-- 点击测试
function btn2:onClick()
    -- 打开 com.androlua 节点对象
    local dir = afs.open('com.androlua')

    -- 创建文件夹节点
    local test = dir:create('test/')

    -- 重命名子节点并更换新对象（原节点对象废弃）
    test = dir:rename('test', 'project')

    -- 节点是否为文件
    print('isFile 1:', test:isFile())

    -- 删除子节点
    dir:remove('project')

    -- 子节点是否存在
    print('exists:', dir:exists('project'))

    -- 打印子节点列表
    local list = dir:list()
    print('list:', dump(list))

    -- 创建文件节点
    local a = dir:create('a.txt')

    -- 文件修改时间
    print('lastModified 1:', a:lastModified())

    -- 写入字符串(效率低)
    a:write('测试')

    -- 写入字符串(仅文本)
    a:writeString('文本')

    -- 写入字节数组
    local bytes = byte[4096]
    a:writeBytes(bytes)

    -- 获取文件长度
    print('length 1:', a:length())

    -- 移动文件句柄到头部（用法同io库）
    a:seek('set')

    -- 读取6字节（效率低）
    a:read(6)

    -- 读取6字节（仅文本）
    a:readString(6)

    -- 读取到字节数组
    local bytes = byte[4096]
    a:readBytes(bytes)

    -- 截断文件到地址6
    a:truncate(6)

    -- 移动文件句柄到尾部2字节处
    a:seek('end', -2)

    -- 读取全部并计算长度
    print('readAll:', #a:read())

    -- 写入缓冲到磁盘
    a:flush()

    -- 关闭节点IO
    a:close()

    -- 子节点是否为文件
    print('isFile 2:', dir:isFile('a.txt'))

    -- 子节点修改时间
    print('lastModified 2:', dir:lastModified('a.txt'))

    -- 子节点大小
    print('length 2:', dir:length('a.txt'))

    -- 创建文件节点
    dir:create('test/'):create('out.txt')

    -- 打开文件节点
    local input = dir:open('a.txt')
    local output = dir:open('test/out.txt')

    -- 复制内容到文件节点
    input:copyTo(output)

    -- 关闭节点IO
    input:close()
    output:close()
end
