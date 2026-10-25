# 没有 Mac 怎么装到 iPhone（免费路线）

> 全程只用你的 **Windows 电脑 + iPhone**，不需要苹果电脑。
> 原理：GitHub 免费提供苹果系统的云服务器帮我们编译出安装包，然后用 Windows 上的免费工具 Sideloadly 把安装包装进你的 iPhone。
> 需要的东西：一个 GitHub 账号（免费）、一个 Apple ID（就是你 iPhone 上用的那个）、一根数据线。

---

## 第一步：注册 GitHub 账号（5 分钟）

1. 浏览器打开 `github.com`，点 **Sign up**。
2. 填邮箱、设密码、起个用户名，按提示完成注册（有中文界面，看不懂英文可用浏览器翻译）。

## 第二步：把代码上传到 GitHub（10 分钟）

1. 登录后点右上角 **「+」→ New repository**。
2. **Repository name** 随便填，比如 `skillclock`。
3. 选 **Public**（公开仓库云端编译永久免费）；
   介意别人看到源码就选 Private（私有每月有免费额度，编译几次够用）。
4. 点 **Create repository**。
5. 在新页面点 **「uploading an existing file」** 链接。
6. 把 `SkillClock` 文件夹里**所有文件和文件夹**（包括 `.github` 文件夹）拖进页面。
   - 注意：`.github` 文件夹是隐藏的，拖的时候别漏掉。看不见的话在文件管理器勾选「查看 → 显示 → 隐藏的项目」。
7. 页面下方点绿色按钮 **Commit changes**。

## 第三步：云端自动打包（约 15 分钟，不用守着）

1. 在仓库页面顶部点 **「Actions」** 标签。
2. 第一次会提示是否启用，点绿色按钮同意。
3. 左侧点 **「云端打包IPA」**，右侧出现 **「Run workflow」** 按钮，点它，再点弹出的绿色 **「Run workflow」**。
4. 等 10–20 分钟，圆圈变成绿色对勾 ✅ 就是成功了。
   - 变成红叉 ❌：点进去看红色日志，把最后几十行红色文字截图/复制发给我，我来修。

## 第四步：下载安装包

1. 点进那个绿色对勾的运行记录。
2. 页面下方 **Artifacts** 区域有个 **「SkillClock-ipa」**，点它下载。
3. 解压下载的 zip，里面就是 `SkillClock.ipa`。

## 第五步：用 Sideloadly 装进 iPhone（10 分钟）

1. Windows 上安装两个苹果官方组件（Sideloadly 运行需要）：
   - 去苹果官网下载 **iTunes**（注意：要下载"Windows 版安装程序"，**不要**装微软商店版）；
   - 同样方式装 **iCloud**（官网版，非商店版）。
2. 打开 `sideloadly.io`，下载安装 **Sideloadly**。
3. 数据线连接 iPhone 和电脑，iPhone 上点 **「信任」** 这台电脑。
4. 打开 Sideloadly：
   - 把 `SkillClock.ipa` 拖进窗口；
   - Apple ID 栏填你 iPhone 用的 Apple ID 邮箱；
   - 点 **「Start」**。
5. 提示输入密码时：
   - 没开双重认证 → 直接填 Apple ID 密码；
   - 开了双重认证 → 先去 `appleid.apple.com` 登录 → 「登录与安全」→「App 专用密码」→ 生成一个，填这个专用密码。
6. 等进度走完，iPhone 桌面就出现「技能时钟」。
7. 第一次打开会提示"不受信任的开发者"：
   到 **设置 → 通用 → VPN与设备管理** → 点你的 Apple ID → 点 **「信任」**。

✅ 完成。打开 App，照《小白教程》操作即可。

## 第六步：每 7 天续一次（免费账号的限制）

免费 Apple ID 签名的 App **7 天后会打不开**，这是苹果的规定。

**全程免费，一分钱不用花。** 只是需要每周续期一次。

### 续期方式 A：数据线（1 分钟）

1. 数据线连电脑，打开 Sideloadly；
2. 再拖一次 `SkillClock.ipa`，点 Start；
3. 装完就又能用 7 天，**App 里的设置和记录不会丢**。

### 续期方式 B：自动续期，不用插线（推荐）

用同为免费的 **AltStore** 代替 Sideloadly，它可以**连数据线都不用自己续**：

1. Windows 上安装 **AltServer**（`altstore.io` 官网下载）；
2. 数据线连一次手机，AltServer 里选 **Install AltStore** 装到手机（只需这一次连线）；
3. 以后只要 **Windows 电脑开着、和手机连同一个 Wi-Fi**，AltServer 会在后台自动续期，你不用做任何事；
4. 想装新的 IPA 时：把 `SkillClock.ipa` 传到手机（微信文件传输/邮件都行），用 AltStore 打开安装即可。

> 习惯用 Sideloadly 也没关系，两种工具可以并存，每周插线续一次就行。

---

## 全程费用一览（都是 0 元）

| 项目 | 费用 |
|---|---|
| GitHub 账号 + 云端编译（公开仓库） | 免费 |
| Sideloadly / AltStore | 免费 |
| Apple ID 签名 | 免费（7 天一续） |
| 后续训练识别模型 | 免费（可用 Google Colab 云端训练，不需要 Mac，到那一步我再教你） |

唯一可选项：付费苹果开发者账号（99 美元/年）可把"7 天一续"变成"一年不用管"。**不买完全不影响使用。**

---

## 常见问题

| 情况 | 处理 |
|---|---|
| GitHub Actions 里没有「Run workflow」按钮 | 确认 `.github` 文件夹传上去了（第二步第 6 条） |
| 编译红叉失败 | 把红色日志发给我 |
| Sideloadly 提示找不到设备 | 换数据线 / 换 USB 口 / iPhone 上点「信任」/ 重开 Sideloadly |
| Sideloadly 提示登录失败 | 用「App 专用密码」，不要用主密码 |
| Sideloadly 提示「maximum number of apps」 | 免费账号最多同时装 3 个自签 App，删掉一个不用的 |
| 手机提示系统版本不够 | 这个 App 需要 iOS 27 以上 |
