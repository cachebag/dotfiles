#!/bin/bash
# Test script to check if LSP attaches and completion works

echo "Testing Neovim LSP and completion..."
echo ""

# Create a test Rust file with Cargo.toml (LSP needs this)
mkdir -p /tmp/nvim_test
cd /tmp/nvim_test

cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF

cat > src/main.rs << 'EOF'
fn main() {
    let x = String::new();
}
EOF

echo "Created test project at /tmp/nvim_test"
echo ""
echo "Now run: cd /tmp/nvim_test && nvim src/main.rs"
echo ""
echo "Once in Neovim:"
echo "1. Press 'i' to enter insert mode"
echo "2. Go to line 2 (after let x = String::new();)"
echo "3. Type: x."
echo "4. You should see autocomplete suggestions like 'push_str', 'len', etc."
echo ""
echo "To check if LSP is attached, run: :LspInfo"
echo "To manually trigger completion, press: <Ctrl-Space>"
echo ""
echo "To check for errors, run: :messages"
