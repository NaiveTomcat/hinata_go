# NDEF 数据集

NDEF 数据集沿用卡包、文件夹、历史记录及导入导出格式，包含一个或多个 NDEF 记录。新建支持文本、URI（包括 `tel:`、`mailto:`、`geo:`）、MIME、外部类型和原始记录。详情可编辑、删除内容和写入标签。未知类型、二进制内容和记录 ID 会保留；分块消息可解析，原始消息在保存时不变。

详情沿用卡片的主体字段样式：纯数据集显示 NDEF 条目数量与 NDEF 数据集大小；扫描的标签另外保留原有 UID / IDm、SAK、ATQA、PMm、System Code 等平台提供的信息和 NDEF 容量。条目细节以「NDEF 数据集」独立分栏、默认展开，可以折叠，不使用交通卡的差分读取。实体标签信息随卡包保存和编辑保留；旧数据仍可载入。手机未暴露的字段不显示。

容量来自系统报告或标签的 NDEF 存储分配；Classic / Type 2 的分配区还需容纳 TLV 头等结构，因此容量不保证等于可写消息的最大长度。实际写入仍单独检查完整编码后的容量。

NDEF 数据集没有游戏刷卡数据，不显示发送按钮，发送服务也会拒绝向游戏实例传输 NDEF。

## 设备支持

| 设备 | 读取 | 写入 |
| --- | --- | --- |
| iPhone | Core NFC 识别的 NDEF 标签，包括 NTAG、FeliCa Type 3、Type 4/5 | 使用系统 NDEF 接口，检查系统报告的容量、可写状态并回读验证；不格式化 Classic |
| Android | 系统识别的 NDEF 标签，包括手机芯片支持的 Classic | NTAG213/215/216 使用原始命令检查；Classic 1K/4K 检查扇区权限并按需格式化；FeliCa 等使用系统 NDEF 接口 |
| HINATA | Type 2、MIFARE Classic MAD/MAD2、FeliCa Type 3（系统码 `12FC`）、Type 4 | NTAG213/215/216、Classic 1K/4K |

MIFARE Classic 使用 Crypto1。格式化为 NDEF 不会改变底层协议，因此不能保证 iPhone 能检测或访问已经格式化的 Classic 卡。应用仅在系统实际提供 NDEF 能力时使用该接口。Android 对 Classic 的支持同样取决于 NFC 芯片。

## 写入检查

- Classic 格式化前检查全部将修改的扇区，验证访问位的反码、数据读写权限和更改完整扇区尾块的权限。只尝试默认密钥、标准 MAD/NDEF 密钥和项目已有的 Aime/Banapass 密钥，不破解未知密钥。
- 新格式采用 MAD/MAD2、标准 NDEF Key A 和可重写的访问条件，不修改 UID。已有 NDEF 卡仅修改 MAD 分配给 NDEF 的扇区，保留目录、密钥和其他应用扇区。NDEF GPB 的只读状态同样会导致拒写。
- NTAG 原始写入检查 GET_VERSION、CC、静态/动态锁位及 AUTH0；拒绝未知型号、保护或锁定状态、不足的容量和需要保留区域映射的非标准 TLV 布局。不会写入 UID、CC、锁定位、密码或配置页。
- 原始写入先将 NDEF 长度置零，写入后才发布最终长度，并验证每个数据块/页及完整消息。原生写入也会回读完整消息。进入实际写入后不提供取消。

写入会覆盖目标 NDEF 内容；格式化会清除 Classic 原有数据，开始前显示确认说明。射频中断或移走卡片仍可能留下空数据或部分格式化状态，需要保持标签位置并重新写入。

## PRiSM 链接

扫描任意 URI 记录或 Smart Poster 中的 `https://link.neri.moe`、`https://link-beta.neri.moe` 链接时，iOS 通过平台通道交给已有的 Swift PRiSM 界面，Android 使用外部浏览器。仅匹配准确主机名，拒绝用户信息及非标准端口。这类扫描不进入卡包历史、游戏发送或 NDEF 详情展示。

## 验证

模拟标签测试覆盖记录编码、保存、恶意/截断消息、Classic 1K/4K 格式化、未知密钥、访问位损坏、只读状态、NTAG 锁位/保护、容量不足、写后回读，以及 Type 3/4 读取。手机 NDEF 接口用平台通道模拟，界面测试覆盖多内容创建、详情写入入口和原生菜单配置。

硬件验收仍需使用真实 NTAG、Classic、FeliCa 及 iOS/Android NFC 设备，特别是多系统 FeliCa、手机 Classic 芯片兼容性和写入中断恢复。

协议参考：[NXP AN10787（MAD）](https://www.nxp.com/docs/en/application-note/AN10787.pdf)、[NXP AN1305（Classic NDEF）](https://www.nxp.com/docs/en/application-note/AN1305.pdf)、[NTAG213/215/216 数据手册](https://www.nxp.com/docs/en/data-sheet/NTAG213_215_216.pdf)、[Apple NFCNDEFTag](https://developer.apple.com/documentation/corenfc/nfcndeftag)。
