#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 XcodeGen，请先执行： brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "缺少 Xcode 命令行工具，请先执行： xcode-select --install" >&2
  exit 1
fi

echo "生成 Xcode 工程..."
xcodegen generate

echo "编译（未签名 Release）..."
xcodebuild \
  -project SkillClock.xcodeproj \
  -scheme SkillClock \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo ""
echo "完成。安装到真机需要你自己的 Apple 开发团队签名。"
echo "下一步： open SkillClock.xcodeproj  → Signing & Capabilities 选 Team → 连上 iPhone 后按 ⌘R"
