#!/bin/bash

set -e

echo -e "\n📦 正在更新系统并安装依赖..."

apt-get update && apt install sudo -y
sudo apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

echo -e "\n🦀 安装 Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup default stable

echo -e "\n📁 检查 nockchain 仓库..."

echo -e "\n📁 检查 nockchain 仓库..."

if [ -d "nockchain" ]; then
  echo "⚠️ 检测到已有 nockchain 目录，是否删除并重新拉取？(y/n)"
  read -r confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm -rf nockchain
    git clone https://github.com/zorp-corp/nockchain
  else
    echo "➡️ 使用已有目录 nockchain"
  fi
else
  git clone https://github.com/zorp-corp/nockchain
fi

# 确保成功进入目录
echo -e "\n🔍 当前目录：$(pwd)"
cd ~/nockchain || { echo "失败，目录不存在！"; exit 1; }
echo -e "\n🔍 成功进入 nockchain 目录：$(pwd)"

echo -e "\n🔧 开始编译，请耐心等待（大约 15 分钟）..."
# Skip the 'install-choo' step
# make install-choo  # Comment this out or delete it
make build-hoon-all
make build


echo -e "\n✅ 编译完成！正在配置环境变量..."
echo 'export PATH="$PATH:/root/nockchain/target/release"' >> ~/.bashrc
echo 'export RUST_LOG=info' >> ~/.bashrc
echo 'export MINIMAL_LOG_FORMAT=true' >> ~/.bashrc
source ~/.bashrc

# === 可选：是否初始化 choo hoon 模块 ===
read -p $'\n🌀 是否执行 choo 初始化测试？这一步可能卡住界面，非必须操作。输入 y 继续，其他跳过(建议 y ）：' confirm_choo
if [[ "$confirm_choo" == "y" || "$confirm_choo" == "Y" ]]; then
  mkdir -p hoon assets
  echo "%trivial" > hoon/trivial.hoon
  choo --new --arbitrary hoon/trivial.hoon
fi

echo -e "\n🔐 正在生成钱包，请保存好助记词与公钥："

if [ -f "./target/release/wallet" ]; then
  ./target/release/wallet keygen | tee wallet_output.txt
elif [ -f "./target/release/nock-wallet" ]; then
  ./target/release/nock-wallet keygen | tee wallet_output.txt
else
  echo -e "\n❌ 无法找到 wallet 命令，请检查构建是否成功。"
  exit 1
fi

pubkey=$(grep -Eo '0x[a-fA-F0-9]{40}' wallet_output.txt)

if [[ -n "$pubkey" ]]; then
  echo -e "\n✅ 已提取公钥：$pubkey"
  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $pubkey|" Makefile
else
  echo -e "\n⚠️ 未能自动提取公钥，请手动输入："
  read -p "请输入你的挖矿公钥: " new_pubkey
  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $new_pubkey|" Makefile
fi

echo -e "\n🧠 配置完成，你可以使用以下命令分别运行 leader 和 follower 节点："

echo -e "\n➡️ 启动 leader 节点："
echo -e "screen -S leader\nmake run-nockchain-leader"

echo -e "\n➡️ 启动 follower 节点："
echo -e "screen -S follower\nmake run-nockchain-follower"

echo -e "\n📄 查看节点日志方法："
echo -e "screen -r leader   # 查看 leader 节点日志"
echo -e "screen -r follower # 查看 follower 节点日志"
echo -e "按 Ctrl+A 再按 D 可退出 screen 会话不关闭程序"

echo -e "\n🎉 所有步骤完成，祝你挖矿愉快！"
