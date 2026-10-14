# 业务数据与实体标签

Aime、Banapass、NDEF 继承 `CardData`，不再继承芯片协议模型。业务字段独立保存，`physicalCard` 可选；它只能包含实体标签模型，不能嵌套另一个 `CardData`。

- 手动创建 Aime / Banapass、扫描 Aime 二维码、新建 NDEF：`physicalCard == null`。
- NFC / HINATA 读取：保留原始标签对象，包括实际 UID / IDm、SAK、ATQA、PMm 等平台提供的字段。
- 扫描时系统未提供 UID：保留一个 ID 未知的实体标签快照，仍与纯数据区分；不生成全零 UID。
- `hasPhysicalCard` 用于区分纯数据和带标签快照的数据。实体快照只是读取来源信息，不限制数据写入其他兼容标签。

FeliCa / AIC、交通卡等原有实体模型保留；FeliCa 刷卡身份依赖真实 IDm，不能通过缺少 IDm 的纯数据替代。

## 保存格式

卡包条目的 UUID、名称、文件夹、来源维持不变。业务数据不再保存顶层 `id`、`sak`、`atqa`，例如：

```json
{
  "type": "aime",
  "physicalCard": null,
  "accessCode": "01234567890123456789"
}
```

读卡获得的实体参数保存在 `physicalCard` 中：

```json
{
  "type": "aime",
  "physicalCard": {
    "type": "iso14443",
    "id": "12345678",
    "sak": 8,
    "atqa": 4
  },
  "accessCode": "01234567890123456789"
}
```

共享调用链中的 `id` / `idString` 作为兼容读取属性，投影到实体标签的 ID；纯数据返回空值。它们不会为纯数据生成或持久化芯片信息。NDEF 原始消息仍用 Base64 保存，容量观测值与未知记录保持不变。

## 旧数据迁移

读取卡包、导入文件和扫描历史时统一解析旧格式，后续保存使用新格式：

- 显式 `physicalCard` 字段优先，`null` 明确表示纯数据。
- 旧 Aime 只有来源明确为 `Direct` / `QR`，且 UID `00000000`、SAK `8`、ATQA `4` 全部匹配旧创建逻辑时，才清理占位参数和 MIFARE Classic 能力标签。
- 旧 Banapass / Aime 没有 UID 时作为纯数据；具有其他 UID 的旧记录保留实体参数。
- 来源未知或 NFC / HINATA 读到的全零 UID 保留，不能仅凭零值判定为占位。
- 旧 NDEF 的顶层 UID 转为实体快照；旧消息、容量及条目内容保留。

## 写入与发送

写入负载从业务数据构建，目标标签由本次扫描单独验证。纯 Aime / Banapass 与带实体快照的相同数据使用相同写入流程。去重比较 Access Code 或实际 Banapass 数据块，不把空 UID 当成相同卡片。

`toJson` 用于本地保存与导入导出；`toRemoteJson` 保持 `SET_CARD_V2` 的原有扁平字段。旧远端要求的 SAK / ATQA 默认值仅在协议适配时补齐；无实体 ID 时发送空字符串，不伪造 UID。Banapass 继续按远端能力选择规范字段或旧数据块格式。

游戏发送能力仍由业务类型决定，NDEF 无论是否携带实体快照都不能发送到游戏。

验证包含旧卡包和历史迁移、实体参数往返、占位来源边界、嵌套数据拒绝、纯数据写入、去重、远端请求格式及详情显示；仍需真实 NFC 设备与远端 DLL 联调。

## 本地私有 cipher

公开仓库中的 `plugins/cardcipher` 是占位接口；实际 Banapass 反向还原由私有 `cardcipher.dart` 实现。当前本地通过 Git 忽略的 `pubspec_overrides.yaml` 指向工作区已有的私有包，与 CI 的私有包覆盖机制一致。

私有实现可从有效 Access Code 解析 serial / keyNumber，并还原 block1 与 block2，因此纯 Banapass 数据也具有写入入口。未从原始块获取的 unknown04 / unknown06 使用既有还原默认值 0 / 3，并在保存中保持一致。

执行 `flutter test` 即可，测试通过库导出的 `BanapassCipher.isAvailable()` 自动决定是否验证仅凭 Access Code 的数据块还原、写入负载、保存往返和无效代码拒绝。公开占位包跳过此项，私有包自动执行。

## 公开与私有构建的功能差异

同一份应用代码仅通过替换 `cardcipher` 占位库或真实库获得功能差异，不需要额外构建开关。两份库导出同名函数 `BanapassCipher.isAvailable()`：公开库返回 `false`，私有库返回 `true`。UI 读取该函数，公开库禁止手动创建 3 开头的卡片并禁用保存；私有库对访问代码继续校验，通过后创建纯 Banapass 数据并反向还原写入所需数据块。其他 Aime 访问代码与 NDEF 数据集创建保持可用。

读取或导入已有 Banapass 数据仍保留原有能力；本限制针对手动新建，不会删除已保存卡片。占位库与真实库均覆盖创建表单与校验测试，并分别验证 Android APK 和 iOS 模拟器构建。
